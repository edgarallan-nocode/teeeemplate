# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      # One subscription per team keeps "is this team paid?" a single lookup.
      t.references :team, null: false, foreign_key: true, index: { unique: true }

      t.string :stripe_subscription_id, null: false
      # The subscription *item* is what carries the seat quantity, so its id is
      # needed to update seats without a round trip to fetch it first.
      t.string :stripe_subscription_item_id
      t.string :stripe_price_id
      t.string :plan_key

      t.string :status, null: false, default: "incomplete"
      t.integer :quantity, null: false, default: 1

      t.datetime :current_period_end
      t.boolean :cancel_at_period_end, null: false, default: false
      t.datetime :canceled_at
      t.datetime :trial_ends_at

      t.timestamps
    end

    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, :status
  end
end
