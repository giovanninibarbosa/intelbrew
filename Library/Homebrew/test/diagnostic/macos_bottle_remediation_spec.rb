# typed: true
# frozen_string_literal: true

require "diagnostic"

RSpec.describe Homebrew::Diagnostic::Checks do
  subject(:checks) { described_class.new }

  describe "#macos_bottle_remediation" do
    test_each(%w[11 13 15.7 26.1]) do |version|
      it "explains retained Intel support and package limitations on macOS #{version}" do
        expect(checks.macos_bottle_remediation(MacOSVersion.new(version), intel: true)).to include(
          "Intelbrew retains support for Intel x86_64",
          "Upstream Homebrew no longer supplies new Intel bottles.",
          "updated formulae may build from source",
          "Individual formulae and casks may not support your macOS version.",
        )
      end
    end

    it "retains alternative guidance below Intelbrew's minimum macOS version" do
      expect(checks.macos_bottle_remediation(MacOSVersion.new("10.15"), intel: true)).to eq <<~EOS
        Homebrew no longer builds bottles for this configuration.
        Consider MacPorts, which provides binary packages for this macOS version:
          https://www.macports.org
      EOS
    end

    it "recommends MacPorts binaries on outdated Apple Silicon macOS" do
      expect(checks.macos_bottle_remediation(MacOSVersion.new("13"), intel: false))
        .to include("MacPorts")
    end

    it "does not recommend alternatives when Homebrew builds bottles" do
      expect(checks.macos_bottle_remediation(MacOSVersion.new("26"), intel: false)).to be_nil
    end

    it "does not assume binary availability on future Intel macOS versions" do
      expect(checks.macos_bottle_remediation(MacOSVersion.new("30"), intel: true)).to be_nil
    end

    it "does not recommend alternatives on pre-release Apple Silicon macOS" do
      expect(checks.macos_bottle_remediation(MacOSVersion.new("30"), intel: false)).to be_nil
    end
  end
end
