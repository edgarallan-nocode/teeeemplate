# frozen_string_literal: true

class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :slug, null: false

      # Stripe customer for this team. Billing belongs to the team, never to an
      # individual user.
      t.string :stripe_customer_id

      t.timestamps
    end

    add_index :teams, :slug, unique: true
    add_index :teams, :stripe_customer_id, unique: true
  end
end
