# frozen_string_literal: true

# The only code allowed to decide what HTML from the rich text editor may reach
# a page.
#
# A rich text field — Project#description is the worked example — is HTML
# written in the browser editor. It is untrusted on the way in and on the way
# out: `sanitize` runs before the model saves and again when a template renders
# through the `rich_text` helper, so a row written before a rule tightened is
# still rendered under the current rule.
#
# Three things here are deliberate:
#
#   * The allowlist is the editor's vocabulary and nothing more. Paragraphs, three
#     heading levels, the inline marks, lists, quotes, code, tables, images and
#     one kind of embed. A tag the editor cannot produce is a tag nobody typed.
#   * An iframe survives only as a YouTube embed whose address *we* built from an
#     extracted id — never the one that arrived. Hosts are matched exactly, so
#     `youtube.com.evil.example` fails.
#   * An `img` needs a web address or one of our own paths — an uploaded picture
#     is served through Active Storage at `/rails/active_storage/…`. Protocol-
#     relative and `data:` sources are dropped.
module RichText
  TAGS = %w[
    p h1 h2 h3 strong em b i u s code a blockquote ul ol li pre br hr
    table thead tbody tr th td img iframe div
  ].freeze

  ATTRIBUTES = %w[
    href rel target src alt title colspan rowspan start class data-youtube-video
    width height frameborder allowfullscreen allow
  ].freeze

  # Elements whose *contents* must go with them. The safe-list sanitiser drops a
  # forbidden tag but keeps its text, which for a paragraph is right and for a
  # script is `alert(1)` left in the body as prose.
  DISCARDED = "script, style, noscript, template, object, embed, svg, math, form, input, button, textarea, select"

  # The one class the sanitiser lets through: a code block's language.
  LANGUAGE_CLASS = /\Alanguage-[a-z0-9+#_-]+\z/i

  # An absolute web address, or a path on this application (`/`, but not `//`,
  # which is protocol-relative and points anywhere).
  IMAGE_SOURCE = %r{\A(https?://|/(?!/))}i

  # Exact hosts, not a suffix match — `notyoutube.com` and `youtube.com.example`
  # must both fail. A video id is eleven characters of [A-Za-z0-9_-].
  YOUTUBE_HOSTS = %w[youtube.com www.youtube.com m.youtube.com youtu.be youtube-nocookie.com www.youtube-nocookie.com].freeze
  YOUTUBE_ID = /\A[\w-]{11}\z/

  def self.sanitize(html)
    return "" if html.blank?

    source = Nokogiri::HTML5.fragment(html.to_s)
    source.css(DISCARDED).each(&:remove)

    clean = Rails::HTML5::SafeListSanitizer.new.sanitize(source.to_html, tags: TAGS, attributes: ATTRIBUTES)
    fragment = Nokogiri::HTML5.fragment(clean)

    scrub_embeds(fragment)
    scrub_images(fragment)
    scrub_wrappers(fragment)
    scrub_classes(fragment)
    trim_trailing_paragraphs(fragment)

    fragment.to_html
  end

  # For a template. Safe because it has just been through #sanitize; nothing else
  # in the application marks a body as safe.
  def self.render(html) = sanitize(html).html_safe # rubocop:disable Rails/OutputSafety

  # The words only, for a list row or a search result. Blocks are separated with
  # a space first, or "<h1>Voice</h1><p>Plain</p>" would read as one word.
  def self.text(html) = Rails::HTML5::FullSanitizer.new.sanitize(html.to_s.gsub("><", "> <")).to_s.squish

  # Whether there is anything to read at all. An editor left empty submits
  # `<p></p>`, which has no text and no block worth keeping.
  def self.blank?(html)
    return true if html.blank?

    text(html).blank? && Nokogiri::HTML5.fragment(html.to_s).css("img, iframe, table").empty?
  end

  # Plain text into paragraphs: blank lines separate them, single newlines break
  # within one. What the migration used for descriptions written before the
  # editor.
  def self.from_plain_text(text)
    text.to_s.split(/\n{2,}/).map(&:strip).reject(&:blank?).map do |paragraph|
      "<p>#{ERB::Util.html_escape(paragraph).gsub("\n", '<br>')}</p>"
    end.join
  end

  # The embed address for a YouTube link in any of its share shapes, or nil for
  # anything else. Rebuilt from the id rather than passed through.
  def self.youtube_embed(url)
    uri = URI.parse(url.to_s.strip)
    return nil unless uri.is_a?(URI::HTTPS) && YOUTUBE_HOSTS.include?(uri.host.to_s.downcase)

    id = youtube_id(uri)
    id&.match?(YOUTUBE_ID) ? "https://www.youtube-nocookie.com/embed/#{id}" : nil
  rescue URI::InvalidURIError
    nil
  end

  def self.youtube_id(uri)
    segments = uri.path.to_s.split("/").reject(&:blank?)
    return segments.first if uri.host.end_with?("youtu.be")

    case segments.first
    when "embed", "shorts", "live", "v" then segments.second
    when "watch" then URI.decode_www_form(uri.query.to_s).to_h["v"]
    end
  end
  private_class_method :youtube_id

  def self.scrub_embeds(fragment)
    fragment.css("iframe").each do |node|
      embed = youtube_embed(node["src"])
      embed ? node["src"] = embed : node.remove
    end
  end
  private_class_method :scrub_embeds

  # A web address or our own path. The safe list allows `data:` for an image,
  # and a megabyte of base64 in a text column is not a picture anybody uploaded.
  def self.scrub_images(fragment)
    fragment.css("img").each do |node|
      node.remove unless node["src"].to_s.match?(IMAGE_SOURCE)
    end
  end
  private_class_method :scrub_images

  def self.scrub_wrappers(fragment)
    fragment.css("div").each do |node|
      next if node.key?("data-youtube-video")

      node.replace(node.children)
    end
  end
  private_class_method :scrub_wrappers

  # The editor keeps an empty paragraph after a final block so there is somewhere
  # to click. That is cursor room, not content, and it grows by one on every
  # save if it is kept.
  def self.trim_trailing_paragraphs(fragment)
    while (last = fragment.children.last) && last.name == "p" && last.children.empty?
      last.remove
    end
  end
  private_class_method :trim_trailing_paragraphs

  def self.scrub_classes(fragment)
    fragment.css("[class]").each do |node|
      next if node.name == "code" && node["class"].to_s.match?(LANGUAGE_CLASS)

      node.remove_attribute("class")
    end
  end
  private_class_method :scrub_classes
end
