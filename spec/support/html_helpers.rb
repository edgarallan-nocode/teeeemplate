# frozen_string_literal: true

module HtmlHelpers
  # Asserting that rendered markup contains a name, an email or any other
  # value that came from a factory is a trap: ERB escapes it, so the moment
  # Faker produces "O'Connell" or "Bloggs & Sons" the raw string is no longer
  # in the response and the spec fails — intermittently, depending on the
  # random seed.
  #
  #   expect(response.body).to include(html(team.name))
  #
  # Use this for anything dynamic. A hard-coded literal you control needs no
  # escaping.
  def html(text) = CGI.escapeHTML(text.to_s)
end
