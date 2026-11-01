# typed: strict
# frozen_string_literal: true

RSpec.describe "brew --version", type: :system do
  it "prints Intelbrew's version", :integration_test do
    expect { brew_sh "--version" }
      .to output(/^Intelbrew #{Regexp.escape(HOMEBREW_VERSION)}\n/o).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end
end
