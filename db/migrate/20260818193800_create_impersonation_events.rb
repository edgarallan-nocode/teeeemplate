# frozen_string_literal: true

class CreateImpersonationEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :impersonation_events do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.references :user, null: false, foreign_key: true

      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.string :ip_address
      t.string :user_agent
      t.string :reason

      t.timestamps
    end

    add_index :impersonation_events, %i[admin_id started_at]
    add_index :impersonation_events, :ended_at
  end
end
