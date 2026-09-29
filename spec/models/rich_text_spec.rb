# frozen_string_literal: true

require "rails_helper"

# The allowlist for a document's HTML, and the two rebuilds that make it safe:
# an embed survives only as an address VideoSource built, a div only as one of
# the two wrappers the editor emits.
RSpec.describe RichText do
  describe ".sanitize" do
    it "keeps the editor's vocabulary" do
      html = "<h1>T</h1><p><strong>b</strong> <em>i</em> <code>c</code> <a href=\"https://x.test\">l</a></p>" \
             "<blockquote><p>q</p></blockquote><ul><li><p>a</p></li></ul><table><tbody><tr><td><p>1</p></td></tr></tbody></table>"

      expect(described_class.sanitize(html)).to eq(html)
    end

    it "strips scripts, handlers and javascript: links" do
      html = %(<p onclick="x()">Hi <script>alert(1)</script><a href="javascript:alert(1)">l</a></p>)

      clean = described_class.sanitize(html)

      expect(clean).not_to include("script", "onclick", "javascript:")
      expect(clean).to include("<a>l</a>")
    end

    # The rule Lesson follows for a video, applied to a second field: what reaches
    # the page is the address we built, never the one that arrived.
    it "rebuilds a YouTube iframe from its id and removes every other iframe" do
      html = %(<div data-youtube-video><iframe src="https://www.youtube.com/watch?v=dQw4w9WgXcQ"></iframe></div>) +
             %(<iframe src="https://evil.example/frame"></iframe>)

      clean = described_class.sanitize(html)

      expect(clean).to include(%(src="https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"))
      expect(clean).not_to include("evil.example")
      expect(clean.scan("<iframe").size).to eq(1)
    end

    it "unwraps any div that is not the video wrapper" do
      html = %(<div class="wrapper"><p>kept</p></div><div data-youtube-video></div>)

      clean = described_class.sanitize(html)

      expect(clean).to eq(%(<p>kept</p><div data-youtube-video=""></div>))
    end

    it "keeps a code block's language class and no other class" do
      html = %(<pre><code class="language-ruby">x</code></pre><p class="fancy">y</p>)

      clean = described_class.sanitize(html)

      expect(clean).to include(%(class="language-ruby"))
      expect(clean).not_to include("fancy")
    end

    # Our own uploads are served at a relative path; a protocol-relative one
    # points at any host, so it is refused with the inline data: kind.
    it "keeps an https or uploaded image and drops data: and protocol-relative ones" do
      html = %(<img src="https://cdn.test/a.png" alt="A"><img src="/rails/active_storage/blobs/redirect/x/a.png">) +
             %(<img src="data:image/png;base64,AAAA"><img src="//evil.example/a.png">)

      clean = described_class.sanitize(html)

      expect(clean).to include(%(src="https://cdn.test/a.png"), %(src="/rails/active_storage/blobs/redirect/x/a.png"))
      expect(clean).not_to include("data:image", "evil.example")
    end
  end

  it "drops the empty paragraphs the editor leaves after the last block" do
    expect(described_class.sanitize("<h1>T</h1><p></p><p></p>")).to eq("<h1>T</h1>")
    expect(described_class.sanitize("<p></p><p>kept</p>")).to eq("<p></p><p>kept</p>")
  end

  describe ".blank?" do
    it "treats an empty editor as blank and a lone image as content" do
      expect(described_class.blank?("<p></p>")).to be(true)
      expect(described_class.blank?("")).to be(true)
      expect(described_class.blank?(%(<img src="https://cdn.test/a.png">))).to be(false)
      expect(described_class.blank?("<p>hi</p>")).to be(false)
    end
  end

  describe ".text" do
    it "returns the words without the markup" do
      expect(described_class.text("<h1>Voice</h1><p>Short <strong>sentences</strong>.</p>")).to eq("Voice Short sentences.")
    end
  end

  describe ".from_plain_text" do
    it "wraps paragraphs, breaks lines and escapes markup" do
      expect(described_class.from_plain_text("One\ntwo\n\n<b>three</b>"))
        .to eq("<p>One<br>two</p><p>&lt;b&gt;three&lt;/b&gt;</p>")
    end
  end
end
