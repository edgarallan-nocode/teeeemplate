# frozen_string_literal: true

# A project's description becomes rich text.
#
# `description` stays the canonical column and becomes HTML — what the page
# renders and what a list row summarises. It is sanitised on the way in and on
# the way out by RichText, which is the only code allowed to decide what may
# reach a page.
#
# `content` is the editor's own JSON for the same text. It is a convenience for
# reopening the editor exactly as it was left, not a second source of truth: when
# it is missing the editor rebuilds it from `description`.
#
# Existing descriptions were plain text rendered with simple_format, so they are
# wrapped into paragraphs here, or the editor would open them as one run-on
# paragraph. Done in the migration because this is the example table on a fresh
# application — see STYLE.md §11 for when a backfill moves to a task.
class AddContentToProjects < ActiveRecord::Migration[8.1]
  class Row < ApplicationRecord
    self.table_name = "projects"
  end

  def up
    add_column :projects, :content, :jsonb

    Row.where.not(description: [ nil, "" ]).find_each do |row|
      next if row.description.lstrip.start_with?("<")

      row.update_columns(description: RichText.from_plain_text(row.description))
    end
  end

  def down
    remove_column :projects, :content
  end
end
