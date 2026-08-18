# frozen_string_literal: true

class AddLastTeamForeignKeyToUsers < ActiveRecord::Migration[8.1]
  def change
    # Nullified rather than cascading: losing a team should not delete the user.
    add_foreign_key :users, :teams, column: :last_team_id, on_delete: :nullify
  end
end
