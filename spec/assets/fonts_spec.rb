# frozen_string_literal: true

require "rails_helper"

# The webfont is easy to break silently: a renamed file, a missed rebuild, or a
# copy that never made it into the repository all fail at runtime rather than at
# build time, and the page just quietly falls back to a system sans.
RSpec.describe "Self-hosted fonts" do
  let(:font_dir) { Rails.root.join("app/assets/fonts") }
  let(:compiled_css) { Rails.root.join("app/assets/builds/application.css") }

  it "ships the Lexend Deca files" do
    expect(font_dir.glob("lexend-deca-*.woff2")).not_to be_empty
  end

  it "resolves every font referenced by the compiled stylesheet" do
    skip "run `npm run build:css` first" unless compiled_css.exist?

    referenced = compiled_css.read.scan(/url\(["']?([^"')]+\.woff2)["']?\)/).flatten.uniq
    expect(referenced).not_to be_empty

    missing = referenced.reject { |name| font_dir.join(File.basename(name)).exist? }
    expect(missing).to be_empty,
      "The stylesheet references fonts that are not in app/assets/fonts: #{missing.join(', ')}"
  end

  it "serves each font through Propshaft, fingerprinted" do
    font_dir.glob("*.woff2").each do |font|
      resolved = Rails.application.assets.load_path.find(font.basename.to_s)

      expect(resolved).to be_present, "Propshaft cannot resolve #{font.basename}"
      expect(resolved.digested_path.to_s).to match(/-[0-9a-f]{8,}\.woff2\z/)
    end
  end

  it "fetches no font from a third-party host" do
    # A CDN font request is render-blocking and hands visitor IPs to the
    # provider. Everything must be served by this application.
    #
    # Only real references count — the comments in base/_fonts.scss name
    # fonts.gstatic.com to explain where the files came from.
    cdn_hosts = /fonts\.(?:googleapis|gstatic)\.com|use\.typekit\.net|cdn\.jsdelivr\.net/

    sources = Rails.root.glob("app/assets/stylesheets/**/*.scss") +
              Rails.root.glob("app/views/layouts/*.erb")

    offenders = sources.select do |file|
      references = file.read.scan(/url\(([^)]*)\)|href=["']([^"']*)["']/).flatten.compact
      references.any? { |reference| reference.match?(cdn_hosts) }
    end

    expect(offenders).to be_empty,
      "These files fetch a font from a third-party host: #{offenders.join(', ')}"
  end

  it "points the type tokens at the self-hosted family" do
    skip "run `npm run build:css` first" unless compiled_css.exist?

    css = compiled_css.read

    expect(css).to include("@font-face")
    expect(css).to match(/--font-body:\s*"Lexend Deca"/)
    expect(css).to match(/--font-display:\s*"Lexend Deca"/)
  end
end
