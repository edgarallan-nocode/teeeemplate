# frozen_string_literal: true

# The example tenant-owned resource. It exists to demonstrate the scoping
# pattern end to end — model concern, policy, query object, controller, views,
# and isolation specs. Delete it when starting a real application.
class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :team, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }

      t.string :name, null: false
      t.text :description
      t.datetime :archived_at

      t.timestamps
    end

    add_index :projects, %i[team_id name]
    add_index :projects, %i[team_id created_at]
  end
end
