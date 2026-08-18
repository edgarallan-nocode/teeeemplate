# frozen_string_literal: true

class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true

      # 0 member, 1 admin, 2 owner. Integer ordering is deliberate so policies
      # can express "admin or above" as a comparison.
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    add_index :memberships, %i[user_id team_id], unique: true
    add_index :memberships, %i[team_id role]
  end
end
