# frozen_string_literal: true

# Email confirmation is no longer required to create an account, and the
# :confirmable module has been removed from User entirely.
#
# The trade-off this accepts: changing an account's email address is no longer
# verified. `config.send_email_changed_notification` is enabled to compensate —
# the previous address is told when the email changes, so a hijacked account
# still produces a signal the real owner can act on.
class RemoveConfirmableFromUsers < ActiveRecord::Migration[8.1]
  def up
    remove_index :users, :confirmation_token, if_exists: true

    remove_column :users, :confirmation_token
    remove_column :users, :confirmed_at
    remove_column :users, :confirmation_sent_at
    remove_column :users, :unconfirmed_email
  end

  def down
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    add_index :users, :confirmation_token, unique: true

    # Existing accounts were usable before this rollback, so treat them as
    # confirmed rather than locking everyone out on the way back.
    up_only_backfill
  end

  private

  def up_only_backfill
    execute <<~SQL.squish
      UPDATE users SET confirmed_at = COALESCE(confirmed_at, created_at)
    SQL
  end
end
