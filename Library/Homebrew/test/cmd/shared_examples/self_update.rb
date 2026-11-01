# typed: strict
# frozen_string_literal: true

require "open3"

RSpec.shared_context "isolated self-update" do
  sig { returns(Pathname) }
  let(:repository_root) { HOMEBREW_LIBRARY_PATH.parent.parent }

  sig { returns(Pathname) }
  let(:test_root) { mktmpdir }

  sig { params(script: String, env: T::Hash[String, T.nilable(String)]).returns([String, String, Process::Status]) }
  def run_update_shell(script, env)
    # Stop Git finding the enclosing checkout, e.g. after a failed `git init`. Use the
    # parent as Git ignores a ceiling that is the current directory (e.g. `test_root`).
    Bundler.with_unbundled_env do
      Open3.capture3(env.merge("GIT_CEILING_DIRECTORIES" => test_root.dirname.to_s), "/bin/bash", "-c", script)
    end
  end

  sig { void }
  def setup_update_utils
    (test_root/"Library/Homebrew/utils").mkpath
    FileUtils.ln_s repository_root/"Library/Homebrew/utils.sh", test_root/"Library/Homebrew/utils.sh"
    %w[api cmd curl executables formatter git lock tool tty].each do |name|
      FileUtils.ln_s repository_root/"Library/Homebrew/utils/#{name}.sh",
                     test_root/"Library/Homebrew/utils/#{name}.sh"
    end
    FileUtils.ln_s repository_root/"Library/Homebrew/utils/lock_sh", test_root/"Library/Homebrew/utils/lock_sh"
  end

  sig { returns(String) }
  let(:fixture_git_executable) { Utils.safe_popen_read(Utils::Git.git, "--homebrew=print-path").chomp }

  sig { returns(Pathname) }
  let(:remote) { test_root/"remote" }

  sig { returns(Pathname) }
  let(:installation) { test_root/"installation" }

  sig { returns(T::Boolean) }
  let(:release_tags) { false }

  sig { params(directory: Pathname, args: String).returns(String) }
  def fixture_git(directory, *args)
    Utils.safe_popen_read(fixture_git_executable, "-C", directory, "-c", "user.name=Homebrew Tests",
                          "-c", "user.email=tests@brew.sh", "-c", "commit.gpgsign=false", *args).chomp
  end

  sig {
    params(command: String, option: String, env: T::Hash[String, T.nilable(String)])
      .returns([String, String, Process::Status])
  }
  def run_self_update(command, option = "", env = {})
    run_update_shell(
      <<~SH,
        source "#{repository_root}/Library/Homebrew/utils/git.sh"
        source "#{repository_root}/Library/Homebrew/cmd/#{command}.sh"
        lock() { :; }
        brew() {
          if [[ "$1" == update-report ]]
          then
            printf 'before=%s after=%s\\n' "${HOMEBREW_UPDATE_BEFORE}" "${HOMEBREW_UPDATE_AFTER}"
          fi
          [[ -z "${HOMEBREW_UPDATE_FAILED}" ]]
        }
        homebrew-#{command} #{option}
      SH
      {
        "GIT_EXECUTABLE"                        => fixture_git_executable,
        "HOMEBREW_GIT"                          => fixture_git_executable,
        "HOMEBREW_BREW_DEFAULT_GIT_REMOTE"      => "https://github.com/giovanninibarbosa/intelbrew",
        "HOMEBREW_BREW_GIT_REMOTE"              => "https://github.com/giovanninibarbosa/intelbrew",
        "HOMEBREW_CACHE"                        => (test_root/"cache").to_s,
        "HOMEBREW_CELLAR"                       => (test_root/"Cellar").to_s,
        "HOMEBREW_CORE_REPOSITORY"              => (installation/"Library/Taps/homebrew/homebrew-core").to_s,
        "HOMEBREW_CASK_REPOSITORY"              => (installation/"Library/Taps/homebrew/homebrew-cask").to_s,
        "HOMEBREW_DEVELOPER"                    => nil,
        "HOMEBREW_DEV_CMD_RUN"                  => nil,
        "HOMEBREW_FORCE_BREWED_CA_CERTIFICATES" => nil,
        "HOMEBREW_FORCE_BREWED_CURL"            => nil,
        "HOMEBREW_FORCE_BREWED_GIT"             => nil,
        "HOMEBREW_LIBRARY"                      => (installation/"Library").to_s,
        "HOMEBREW_NO_ENV_HINTS"                 => "1",
        "HOMEBREW_NO_INSTALL_FROM_API"          => "1",
        "HOMEBREW_NO_UPDATE_CLEANUP"            => nil,
        "HOMEBREW_PREFIX"                       => test_root.to_s,
        "HOMEBREW_REPOSITORY"                   => installation.to_s,
        "HOMEBREW_UPDATE_TO_TAG"                => nil,
        "HOMEBREW_USER_SET_VARS"                => "",
      }.merge(env),
    )
  end

  sig { returns(Pathname) }
  let(:tap_remote) { test_root/"tap-remote" }

  sig { returns(Pathname) }
  let(:tap) { installation/"Library/Taps/third-party/homebrew-tools" }

  sig { void }
  def setup_self_update_tap
    fixture_git(test_root, "clone", "--quiet", remote.to_s, tap_remote.to_s)
    fixture_git(tap_remote, "branch", "-m", "tap-track")
    tap.dirname.mkpath
    fixture_git(test_root, "clone", "--quiet", tap_remote.to_s, tap.to_s)
    fixture_git(tap_remote, "commit", "--quiet", "--allow-empty", "-m", "Tap update")
  end

  sig { void }
  def setup_self_update
    remote.mkpath
    fixture_git(remote, "init", "--quiet", "--initial-branch=fork-tip")
    (remote/"tracked").write "initial\n"
    fixture_git(remote, "add", "tracked")
    fixture_git(remote, "commit", "--quiet", "-m", "Initial")
    fixture_git(remote, "tag", "99.0.0")
    fixture_git(remote, "tag", "intelbrew-7.0.2") if release_tags
    fixture_git(test_root, "clone", "--quiet", remote.to_s, installation.to_s)
    (remote/"tracked").write "release\n"
    fixture_git(remote, "commit", "--quiet", "-am", "Release")
    fixture_git(remote, "tag", "intelbrew-7.0.10") if release_tags
    (remote/"tracked").write "branch tip\n"
    fixture_git(remote, "commit", "--quiet", "-am", "Development")
    %w[intelbrew-8.0.0-rc1 intelbrew-9.0 intelbrew-10.0.0.1 intelbrew-11.x.0].each do |tag|
      fixture_git(remote, "tag", tag)
    end
    setup_update_utils
    FileUtils.ln_s test_root/"Library", installation/"Library"
    FileUtils.ln_s repository_root/"Library/Homebrew/shims", test_root/"Library/Homebrew/shims"
    (installation/".git/info/exclude").append_lines "Library\nmarker"
  end
end
