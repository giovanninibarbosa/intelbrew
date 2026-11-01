# typed: true
# frozen_string_literal: true

require "cmd/shared_examples/self_update"

RSpec.describe "brew update-reset", type: :system do
  include_context "isolated self-update"

  after do
    FileUtils.rm_rf test_root
  end

  it_behaves_like "a documented command", "update-reset", shell: true

  describe "fork self-updates" do
    before { setup_self_update }

    it "resets to the fork default branch with inherited tags" do
      _stdout, stderr, status = run_self_update("update-reset")

      expect([status.success?, fixture_git(installation, "rev-parse", "HEAD"),
              fixture_git(installation, "branch", "--show-current")])
        .to eq([true, fixture_git(remote, "rev-parse", "HEAD"), "fork-tip"]), stderr
    end

    it "preserves brew and tap remotes and the tap default branch" do
      setup_self_update_tap
      _stdout, stderr, status = run_self_update("update-reset")

      expect([status.success?, fixture_git(installation, "remote", "get-url", "origin"),
              fixture_git(tap, "remote", "get-url", "origin"), fixture_git(tap, "rev-parse", "HEAD"),
              fixture_git(tap, "branch", "--show-current")])
        .to eq([true, remote.to_s, tap_remote.to_s, fixture_git(tap_remote, "rev-parse", "HEAD"),
                "tap-track"]), stderr
    end

    it "fails before discarding local files when fork releases are missing" do
      original_revision = fixture_git(installation, "rev-parse", "HEAD")
      (installation/"marker").write "keep me\n"
      (installation/"tracked").write "local changes\n"
      _stdout, stderr, status = run_self_update("update-reset", "", "HOMEBREW_UPDATE_TO_TAG" => "1")

      expect([status.success?, stderr.include?("intelbrew-X.Y.Z"),
              stderr.include?("HOMEBREW_UPDATE_TO_TAG"), fixture_git(installation, "rev-parse", "HEAD"),
              (installation/"marker").read, (installation/"tracked").read])
        .to eq([false, true, true, original_revision, "keep me\n", "local changes\n"])
    end

    it "validates missing fork releases before resetting an explicitly listed tap" do
      setup_self_update_tap
      original_revision = fixture_git(tap, "rev-parse", "HEAD")
      (tap/"tracked").write "local tap changes\n"
      _stdout, stderr, status = run_self_update(
        "update-reset", "#{tap.to_s.shellescape} #{installation.to_s.shellescape}", "HOMEBREW_UPDATE_TO_TAG" => "1"
      )

      expect([status.success?, stderr.include?("intelbrew-X.Y.Z"),
              fixture_git(tap, "rev-parse", "HEAD"), (tap/"tracked").read])
        .to eq([false, true, original_revision, "local tap changes\n"])
    end

    context "with fork releases" do
      let(:release_tags) { true }

      it "resets to the highest valid namespaced release when explicitly requested" do
        _stdout, stderr, status = run_self_update("update-reset", "", "HOMEBREW_UPDATE_TO_TAG" => "1")

        expect([status.success?, fixture_git(installation, "rev-parse", "HEAD"),
                fixture_git(installation, "branch", "--show-current")])
          .to eq([true, fixture_git(remote, "rev-parse", "intelbrew-7.0.10"), "stable"]), stderr
      end
    end
  end
end
