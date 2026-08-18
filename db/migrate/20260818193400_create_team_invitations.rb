# frozen_string_literal: true

class CreateTeamInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :team_invitations do |t|
      t.references :team, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }

      t.string :email, null: false
      t.integer :role, null: false, default: 0
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.references :accepted_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :team_invitations, :token, unique: true

    # One live invitation per email per team. Accepted invitations are kept as
    # history and are excluded from the constraint.
    add_index :team_invitations, %i[team_id email],
              unique: true,
              where: "accepted_at IS NULL",
              name: "index_team_invitations_pending_on_team_and_email"
  end
end
