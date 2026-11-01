# typed: true
# frozen_string_literal: true

require "open3"

RSpec.describe "Bash" do
  matcher :have_valid_bash_syntax do
    T.bind(self, T.class_of(RSpec::Matchers::DSL::Matcher))
    match do |file|
      stdout, stderr, status = Open3.capture3("/bin/bash", "-n", file)

      @actual = [file, stderr]

      stdout.empty? && status.success?
    end

    failure_message do |(file, stderr)|
      "expected that #{file} is a valid Bash file:\n#{stderr}"
    end
  end

  describe "brew" do
    subject(:brew) { HOMEBREW_LIBRARY_PATH.parent.parent/"bin/brew" }

    it { is_expected.to have_valid_bash_syntax }

    it "rejects mismatched real and effective UIDs before dispatching a command" do
      results = [[1000, 1001], [0, 1000], [1000, 0]].map do |uid, euid|
        # Bash's UID and EUID are read-only, so substitute them in the script.
        script = brew.read.gsub("${UID}", uid.to_s).gsub("${EUID}", euid.to_s)
        stdout, stderr, status = Open3.capture3("/bin/bash", "-puc", script, brew.to_s, "--prefix")
        [stdout, stderr, status.exitstatus]
      end

      expect(results)
        .to all(eq(["", "Error: Running Homebrew with different real and effective UIDs is not supported.\n", 1]))
    end
  end

  describe "help" do
    it "documents installation and directs users to the Intelbrew guide" do
      stdout, stderr, status = Open3.capture3(
        "/bin/bash", "-c", 'source "$1"; homebrew-help --help',
        "bash", (HOMEBREW_LIBRARY_PATH/"help.sh").to_s
      )

      expect([stdout, stderr, status.success?]).to match([
        include("brew install FORMULA|CASK...",
                "https://github.com/giovanninibarbosa/intelbrew/blob/HEAD/docs/Intelbrew.md"),
        "", true
      ])
    end
  end

  describe "bootstrap Git remotes" do
    test_each([nil, "https://example.com/custom/brew"]) do |override|
      it "exports the brew remote with #{override || "the fork default"}" do
        stdout, stderr, status = Open3.capture3(
          { "HOMEBREW_LIBRARY" => HOMEBREW_LIBRARY_PATH.parent.to_s,
            "HOMEBREW_REPOSITORY" => mktmpdir.to_s, "HOMEBREW_BREW_GIT_REMOTE" => override,
            "HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_DEVELOPER" => "1" },
          "/bin/bash", "-c", <<~'BASH'
            source() {
              case "$1" in
                */utils/analytics.sh)
                  printf '%s\n' "${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}" "${HOMEBREW_BREW_GIT_REMOTE}" \
                    "${HOMEBREW_CORE_GIT_REMOTE}"
                  exit 0
                  ;;
                *) builtin source "$@" ;;
              esac
            }
            source "${HOMEBREW_LIBRARY}/Homebrew/brew.sh" config
          BASH
        )

        expect([status.success?, stdout, stderr]).to eq(
          [true, "https://github.com/giovanninibarbosa/intelbrew\n" \
                 "#{override || "https://github.com/giovanninibarbosa/intelbrew"}\n" \
                 "https://github.com/Homebrew/homebrew-core\n", ""],
        )
      end
    end
  end

  test_each(%w[formulae casks]) do |command|
    describe "brew #{command}" do
      before do
        ENV["HOMEBREW_LIBRARY"] = HOMEBREW_LIBRARY_PATH.parent.to_s
        ENV["HOMEBREW_NO_REQUIRE_TAP_TRUST"] = nil
      end

      it "skips the Bash fast path when Ruby is required" do
        ENV["HOMEBREW_FORCE_RUBY_COMMAND"] = "1"
        stdout, stderr, status = Open3.capture3(
          "/bin/bash", "-c", <<~BASH, "bash", command
            source() {
              case "$1" in
                */cmd/formulae.sh | */cmd/casks.sh) echo 'Bash fast path'; exit 1 ;;
                */help.sh) echo 'Ruby fallback'; exit 0 ;;
                *) builtin source "$@" ;;
              esac
            }
            source "${HOMEBREW_LIBRARY}/Homebrew/brew.sh" "$1"
          BASH
        )

        expect([stdout, stderr, status.success?]).to eq(["Ruby fallback\n", "", true])
      end

      it "does not fall back to Ruby when the output pipe closes" do
        cache = mktmpdir
        ENV["HOMEBREW_NO_INSTALL_FROM_API"] = nil
        ENV["HOMEBREW_CACHE"] = cache.to_s
        (cache/"api").mkpath
        (cache/"api/#{(command == "formulae") ? "formula" : "cask"}_names.txt")
          .write((1..10_000).map { |i| format("item%05d\n", i) }.join)

        stdout, stderr, status = Open3.capture3(
          "/bin/bash", "-c", <<~BASH, "bash", command
            source "${HOMEBREW_LIBRARY}/Homebrew/cmd/$1.sh"
            homebrew-trusted-items() { return 0; }
            HOMEBREW_BREW_FILE=/usr/bin/false
            "homebrew-$1" | head -n 1
          BASH
        )

        expect([stdout, stderr, status.success?]).to eq(["\n", "", true])
      end
    end
  end

  describe "setup-locale" do
    it "uses the macOS locale charmap rather than the locale name", :needs_macos do
      setup_locale = [
        "/bin/bash", "-c", <<~BASH, "bash", (HOMEBREW_LIBRARY_PATH/"utils/os.sh").to_s
          source "$1"
          locale() {
            [[ "${LC_CTYPE:-${LANG:-}}" == "UTF-8" ]] && printf "UTF-8" || printf "US-ASCII"
          }
          setup-locale
          printf "%s" "${LC_ALL-unset}"
        BASH
      ]
      invalid_stdout, invalid_stderr, invalid_status = Open3.capture3(
        { "LANG" => "C.utf8", "LC_CTYPE" => nil, "LC_ALL" => nil }, *setup_locale
      )
      valid_stdout, valid_stderr, valid_status = Open3.capture3(
        { "LANG" => nil, "LC_CTYPE" => "UTF-8", "LC_ALL" => nil }, *setup_locale
      )

      expect([invalid_stdout, invalid_stderr, invalid_status.success?,
              valid_stdout, valid_stderr, valid_status.success?])
        .to eq(["en_US.UTF-8", "", true, "unset", "", true])
    end

    it "restores filtered Linux locale variables and removes their copies" do
      stdout, stderr, status = Open3.capture3(
        { "LANG" => nil, "LC_CTYPE" => nil, "LC_ALL" => nil },
        "/bin/bash", "-c", <<~'BASH', "bash", (HOMEBREW_LIBRARY_PATH/"utils/os.sh").to_s
          source "$1"
          HOMEBREW_MACOS=
          HOMEBREW_LANG=C
          HOMEBREW_LC_CTYPE=C
          HOMEBREW_LC_ALL=C.UTF-8
          locale() {
            if [[ "$1" == "charmap" ]]
            then
              [[ "${LC_ALL:-}" == "C.UTF-8" ]] && printf "UTF-8" || printf "US-ASCII"
            else
              printf "locale -a called\n" >&2
              printf "C.UTF-8\n"
            fi
          }
          setup-locale
          printf "%s\n" "${LANG-unset}" "${LC_CTYPE-unset}" "${LC_ALL-unset}" \
            "${HOMEBREW_LANG-unset}" "${HOMEBREW_LC_CTYPE-unset}" "${HOMEBREW_LC_ALL-unset}"
        BASH
      )

      expect([stdout, stderr, status.success?])
        .to eq(["C\nC\nC.UTF-8\nunset\nunset\nunset\n", "", true])
    end
  end

  describe "Git release metadata" do
    let(:repository) { mktmpdir }
    let(:revision) { Utils.safe_popen_read("git", "-C", repository, "rev-parse", "HEAD").chomp }
    let(:version_script) do
      <<~BASH
        source "$1"
        HOMEBREW_VERSION=
        set-homebrew-version-from-git
        printf "%s" "${HOMEBREW_VERSION}"
      BASH
    end

    before do
      system "git", "-C", repository, "init", "--quiet", exception: true
      (repository/"tracked").write "initial\n"
      system "git", "-C", repository, "add", "tracked", exception: true
      system "git", "-C", repository, "-c", "user.name=Homebrew Tests", "-c", "user.email=tests@brew.sh",
             "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Initial commit", exception: true
      %w[99.0.0 intelbrew-8.0.0-rc1 intelbrew-9.0 intelbrew-10.0.0.1 intelbrew-11.x.0].each do |tag|
        system "git", "-C", repository, "tag", tag, exception: true
      end
      ENV["HOMEBREW_GIT"] = "git"
      ENV["HOMEBREW_REPOSITORY"] = repository.to_s
    end

    it "selects the highest valid Intelbrew release by version" do
      %w[intelbrew-7.0.2 intelbrew-7.0.10].each do |tag|
        system "git", "-C", repository, "tag", tag, exception: true
      end
      stdout, stderr, status = Open3.capture3(
        "/bin/bash", "-o", "pipefail", "-c", 'source "$1"; latest-intelbrew-tag "$2"',
        "bash", (HOMEBREW_LIBRARY_PATH/"utils/git.sh").to_s, repository.to_s
      )

      expect([stdout, stderr, status.success?]).to eq(["intelbrew-7.0.10\n", "", true])
    end

    it "fails without output when no valid Intelbrew release exists" do
      stdout, stderr, status = Open3.capture3(
        "/bin/bash", "-c", 'source "$1"; latest-intelbrew-tag "$2"',
        "bash", (HOMEBREW_LIBRARY_PATH/"utils/git.sh").to_s, repository.to_s
      )

      expect([stdout, stderr, status.success?]).to eq(["", "", false])
    end

    it "normalises a freshly described Intelbrew release and caches it" do
      system "git", "-C", repository, "tag", "intelbrew-7.0.10", exception: true
      stdout, stderr, status = Open3.capture3(
        "/bin/bash", "-c", version_script, "bash", (HOMEBREW_LIBRARY_PATH/"utils/git.sh").to_s
      )

      expect([stdout, stderr, status.success?, (repository/".git/describe-cache"/revision).read])
        .to eq(["7.0.10", "", true, "7.0.10\n"])
    end

    it "normalises a previously cached Intelbrew release" do
      (repository/".git/describe-cache").mkpath
      (repository/".git/describe-cache"/revision).write "intelbrew-7.0.10\n"
      stdout, stderr, status = Open3.capture3(
        "/bin/bash", "-c", version_script, "bash", (HOMEBREW_LIBRARY_PATH/"utils/git.sh").to_s
      )

      expect([stdout, stderr, status.success?]).to eq(["7.0.10", "", true])
    end

    it "uses a reachable fork release when a newer release is unreachable" do
      system "git", "-C", repository, "tag", "intelbrew-7.0.10", exception: true
      system "git", "-C", repository, "-c", "user.name=Homebrew Tests", "-c", "user.email=tests@brew.sh",
             "-c", "commit.gpgsign=false", "commit", "--quiet", "--allow-empty", "-m", "Other branch", exception: true
      system "git", "-C", repository, "tag", "intelbrew-8.0.0", exception: true
      system "git", "-C", repository, "reset", "--quiet", "--hard", "HEAD~", exception: true
      stdout, stderr, status = Open3.capture3(
        "/bin/bash", "-c", version_script, "bash", (HOMEBREW_LIBRARY_PATH/"utils/git.sh").to_s
      )

      expect([stdout, stderr, status.success?]).to eq(["7.0.10", "", true])
    end

    it "preserves a dirty Intelbrew development suffix" do
      system "git", "-C", repository, "tag", "intelbrew-7.0.10", "HEAD", exception: true
      system "git", "-C", repository, "-c", "user.name=Homebrew Tests", "-c", "user.email=tests@brew.sh",
             "-c", "commit.gpgsign=false", "commit", "--quiet", "--allow-empty", "-m", "Development", exception: true
      (repository/"tracked").write "dirty\n"
      ENV["HOMEBREW_DEVELOPER"] = "1"
      stdout, stderr, status = Open3.capture3(
        "/bin/bash", "-c", version_script, "bash", (HOMEBREW_LIBRARY_PATH/"utils/git.sh").to_s
      )

      expect([stdout, stderr, status.success?]).to eq(["7.0.10-1-g#{revision[0, 7]}-dirty", "", true])
    end

    it "preserves an inherited upstream development version before the first fork release" do
      system "git", "-C", repository, "-c", "user.name=Homebrew Tests", "-c", "user.email=tests@brew.sh",
             "-c", "commit.gpgsign=false", "commit", "--quiet", "--allow-empty", "-m", "Development", exception: true
      system "git", "-C", repository, "tag", "intelbrew-12.0.0-beta", exception: true
      stdout, stderr, status = Open3.capture3(
        "/bin/bash", "-c", version_script, "bash", (HOMEBREW_LIBRARY_PATH/"utils/git.sh").to_s
      )

      expect([stdout, stderr, status.success?]).to eq(["99.0.0-1-g#{revision[0, 7]}", "", true])
    end
  end

  describe "set-homebrew-version-from-git" do
    it "writes the cache when the current user owns the Git directory" do
      Dir.mktmpdir("brew-git-cache-") do |tmpdir|
        repository = Pathname(tmpdir)
        revision = "0123456789abcdef0123456789abcdef01234567"
        (repository/".git/refs/heads").mkpath
        (repository/".git/HEAD").write "ref: refs/heads/main\n"
        (repository/".git/refs/heads/main").write "#{revision}\n"

        stdout, stderr, status = Open3.capture3(
          { "HOMEBREW_GIT" => "git", "HOMEBREW_REPOSITORY" => repository.to_s },
          "/bin/bash", "-c", <<~BASH, "bash", (HOMEBREW_LIBRARY_PATH/"utils/git.sh").to_s
            source "$1"
            git() {
              [[ "$*" == *"describe --tags"* ]] && printf "1.2.3"
            }
            HOMEBREW_VERSION=
            set-homebrew-version-from-git
            printf "%s" "${HOMEBREW_VERSION}"
          BASH
        )

        cache_file = repository/".git/describe-cache"/revision
        expect([stdout, stderr, status.success?, cache_file.read]).to eq(["1.2.3", "", true, "1.2.3\n"])
      end
    end

    it "does not mutate the cache when the current user does not own the Git directory" do
      skip "User is root so the root directory is owned by the current user." if Process.euid.zero?

      Dir.mktmpdir("brew-git-cache-") do |tmpdir|
        repository = Pathname(tmpdir)
        (repository/".git").make_symlink "/"
        operations = repository/"operations"

        stdout, stderr, status = Open3.capture3(
          { "HOMEBREW_GIT" => "git", "HOMEBREW_REPOSITORY" => repository.to_s },
          "/bin/bash", "-c", <<~'BASH', "bash", (HOMEBREW_LIBRARY_PATH/"utils/git.sh").to_s, operations.to_s
            source "$1"
            operations="$2"
            git() {
              case "$*" in
                *"rev-parse HEAD") printf "0123456789abcdef0123456789abcdef01234567" ;;
                *"describe --tags"*) printf "1.2.3" ;;
                *) return 1 ;;
              esac
            }
            rm() { printf "rm\n" >>"${operations}"; }
            mkdir() { printf "mkdir\n" >>"${operations}"; }
            HOMEBREW_VERSION=
            set-homebrew-version-from-git
            printf "%s" "${HOMEBREW_VERSION}"
          BASH
        )

        expect([stdout, stderr, status.success?, operations.exist?]).to eq(["1.2.3", "", true, false])
      end
    end
  end

  describe "every `.sh` file" do
    it "has valid Bash syntax" do
      Pathname.glob("#{HOMEBREW_LIBRARY_PATH}/**/*.sh").each do |path|
        relative_path = path.relative_path_from(HOMEBREW_LIBRARY_PATH)
        next if relative_path.to_s.start_with?("shims/", "test/", "vendor/")

        expect(path).to have_valid_bash_syntax
      end
    end
  end

  describe "Bash completion" do
    subject { HOMEBREW_LIBRARY_PATH.parent.parent/"completions/bash/brew" }

    it { is_expected.to have_valid_bash_syntax }
  end

  describe "every shim script" do
    it "has valid Bash syntax" do
      # These have no file extension, but can be identified by their shebang.
      (HOMEBREW_LIBRARY_PATH/"shims").find do |path|
        next if path.directory?
        next if path.symlink?
        next unless path.executable?
        next if path.basename.to_s == "cc" # `bash -n` tries to parse the Ruby part
        next if path.read(12) != "#!/bin/bash\n"

        expect(path).to have_valid_bash_syntax
      end
    end
  end
end
