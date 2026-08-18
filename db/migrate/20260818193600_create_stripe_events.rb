# frozen_string_literal: true

class CreateStripeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_events do |t|
      # The unique index is the idempotency mechanism. Stripe redelivers events,
      # and the second insert is expected to fail — that failure is how the
      # webhook endpoint recognises a duplicate.
      t.string :stripe_event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}

      t.datetime :processed_at
      t.datetime :failed_at
      t.text :error_message
      t.integer :attempts, null: false, default: 0

      t.timestamps
    end

    add_index :stripe_events, :stripe_event_id, unique: true
    add_index :stripe_events, :event_type
    add_index :stripe_events, :processed_at
  end
end
