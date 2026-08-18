# frozen_string_literal: true

require "rails_helper"

# bin/setup copies .env.example to .env, and foreman reads .env at startup with
# whatever encoding the ambient locale implies. A single smart quote or em dash
# in this file therefore crashes `bin/dev` with
# "invalid byte sequence in US-ASCII" on any machine where LANG is not set to a
# UTF-8 locale — which includes plenty of CI runners and bare server shells.
RSpec.describe ".env.example" do
  let(:path) { Rails.root.join(".env.example") }
  let(:contents) { path.read }

  it "exists, because bin/setup copies it" do
    expect(path).to exist
  end

  it "is ASCII only" do
    offenders = contents.each_line.with_index(1).filter_map do |line, number|
      "  line #{number}: #{line.strip}" unless line.ascii_only?
    end

    expect(offenders).to be_empty,
      "Non-ASCII characters break `bin/dev` under a non-UTF-8 locale:\n#{offenders.join("\n")}"
  end

  it "holds no secrets" do
    # Secrets live in Rails credentials. This file is committed.
    expect(contents).not_to match(/\bsk_(?:live|test)_\w/)
    expect(contents).not_to match(/\bwhsec_\w/)
    expect(contents).not_to match(/\bAKIA[0-9A-Z]{16}\b/)
  end

  it "documents every environment variable the application reads" do
    documented = contents.scan(/^#?\s*([A-Z][A-Z0-9_]+)=/).flatten.to_set

    referenced = Rails.root.glob("{app,config,lib}/**/*.rb").flat_map do |file|
      file.read.scan(/ENV(?:\.fetch)?\[?["']([A-Z][A-Z0-9_]+)["']/).flatten
    end.to_set

    # Set by the platform, by Rails, or by bundler - not things a developer
    # configures, so they do not belong in .env.example.
    ignored = %w[
      RAILS_ENV RAILS_MASTER_KEY SECRET_KEY_BASE PATH HOME
      BUNDLE_GEMFILE CI PIDFILE
    ].to_set

    missing = referenced - documented - ignored

    expect(missing).to be_empty,
      "These variables are read by the code but not documented in .env.example: " \
      "#{missing.to_a.sort.join(', ')}"
  end
end
