# frozen_string_literal: true

require "rails_helper"

# The editor, exercised in a real browser. Tagged :js because none of it exists
# until rich_text_editor_controller.js runs.
#
# Kept to the promises that would quietly break: the slash menu opens, filters
# and inserts; the toolbar appears over a selection and formats it; a picture
# chosen from the prompt is uploaded; and what the form saves is both the HTML
# and the editor's JSON for the same text.
RSpec.describe "Rich text editor", :js do
  let(:user) { create(:user) }
  let(:team) { create(:team, name: "Northwind") }
  let!(:membership) { create(:membership, user: user, team: team) }
  let(:project) { create(:project, team: team, name: "Relaunch", description: nil) }

  before do
    sign_in_through_form(user)
    # The dashboard, so the sign-in has landed before the next visit — without
    # this the visit races the redirect and finds the sign-in page again. A
    # finder rather than an expectation: it waits the same way and a hook is
    # for setup, not assertions.
    find("h1", text: team.name)
  end

  def open_editor
    visit edit_project_path(project)
    # Waits for the controller to have mounted the editor.
    find(".editor__content")
  end

  it "shows a placeholder until something is typed" do
    open_editor

    expect(page).to have_css(".editor__content .is-editor-empty[data-placeholder]")
    find(".editor__content").send_keys("Hello")
    expect(page).not_to have_css(".is-editor-empty")
  end

  it "opens the slash menu, filters it, and inserts a heading from the submenu" do
    open_editor
    surface = find(".editor__content")
    surface.click

    surface.send_keys("/")
    expect(page).to have_css(".slash-menu .slash-menu__label", text: /formatting/i)
    expect(page).to have_css(".slash-menu .slash-menu__label", text: /blocks/i)
    expect(page).to have_css(".slash-menu__item", text: "Table")

    surface.send_keys("hea")
    # The filter row first: it waits for the typing to land, so the absence check
    # below runs against the filtered list rather than the one before it.
    expect(page).to have_css(".slash-menu__filter", text: "hea")
    expect(page).to have_css(".slash-menu__item", text: "Heading")
    expect(page).not_to have_css(".slash-menu__item", text: "Table")

    surface.send_keys(:enter) # opens the Heading submenu
    expect(page).to have_css(".slash-menu__item", text: "Heading 2")

    surface.send_keys(:arrow_down, :enter) # Heading 2
    expect(page).not_to have_css(".slash-menu")
    surface.send_keys("Tone")

    expect(page).to have_css(".editor__content h2", text: "Tone")
    # The typed `/hea` was replaced by the block, not left in front of it.
    expect(page).not_to have_css(".editor__content", text: "/hea")
  end

  it "closes the slash menu on Escape and inserts a table by clicking" do
    open_editor
    surface = find(".editor__content")
    surface.click

    surface.send_keys("/")
    expect(page).to have_css(".slash-menu")
    surface.send_keys(:escape)
    expect(page).not_to have_css(".slash-menu")

    surface.send_keys(:backspace, "/tab")
    # Wait for the fresh menu to show the typed query before clicking into it;
    # deleting the slash closes one menu and typing it opens another.
    expect(page).to have_css(".slash-menu__filter", text: "tab")
    find(".slash-menu__item", text: "Table").click

    expect(page).to have_css(".editor__content table")
    expect(page).to have_css(".editor__content th", count: 3)
    expect(page).to have_css(".editor__content tr", count: 3)
    # The caret is inside the table, so the toolbar offers its controls.
    expect(page).to have_css(".editor-toolbar [aria-label='Add row below']")
  end

  it "shows the floating toolbar over a selection, formats it, and saves both formats" do
    open_editor
    surface = find(".editor__content")
    surface.click
    surface.send_keys("Plain words")
    expect(page).not_to have_css(".editor-toolbar")

    surface.send_keys([ :shift, :home ])
    expect(page).to have_css(".editor-toolbar")
    expect(page).to have_css(".editor-toolbar__select", text: "Paragraph")

    find(".editor-toolbar__button[data-mark='bold']").click
    expect(page).to have_css(".editor__content strong", text: "Plain words")
    expect(page).to have_css(".editor-toolbar__button[data-mark='bold'][aria-pressed='true']")

    find(".editor-toolbar__select").click
    find(".editor-menu__item", text: "Heading 1").click
    expect(page).to have_css(".editor__content h1 strong", text: "Plain words")

    click_button "Update Project"
    # The page after the redirect, so the record is committed before it is read.
    expect(page).to have_content("Project updated")

    project.reload
    expect(project.description).to eq("<h1><strong>Plain words</strong></h1>")
    expect(project.content.dig("content", 0, "type")).to eq("heading")
    expect(project.content.dig("content", 0, "content", 0, "marks", 0, "type")).to eq("bold")
  end

  it "uploads a picture chosen from the image prompt and stores its address" do
    open_editor
    surface = find(".editor__content")
    surface.click

    surface.send_keys("/ima", :enter)
    expect(page).to have_css(".editor-popover--block")
    attach_file(Rails.root.join("spec/fixtures/files/logo.png"), make_visible: true) do
      find(".editor-popover--block input[type='file']").click
    end

    expect(page).to have_css(".editor__content img[src*='/rails/active_storage/']")
    expect(project.images.count).to eq(1)

    click_button "Update Project"
    expect(page).to have_content("Project updated")

    expect(project.reload.description).to include("/rails/active_storage/")
    expect(project.content["content"].map { |node| node["type"] }).to include("image")
  end

  it "reopens a saved description from its JSON with the blocks intact" do
    project.update!(description: "<h2>Scope</h2><p>Two pages.</p>",
                    content: { type: "doc", content: [
                      { type: "heading", attrs: { level: 2 }, content: [ { type: "text", text: "Scope" } ] },
                      { type: "paragraph", content: [ { type: "text", text: "Two pages." } ] }
                    ] })

    visit edit_project_path(project)

    expect(page).to have_css(".editor__content h2", text: "Scope")
    expect(page).to have_css(".editor__content p", text: "Two pages.")
  end
end
