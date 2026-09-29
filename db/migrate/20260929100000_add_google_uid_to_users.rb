# frozen_string_literal: true

# Sign in with Google. A user may carry the stable subject id of one Google
# account; the index is partial so users without one do not collide on NULL —
# the same shape as index_users_on_admin. See SKILL.md §2a.
class AddGoogleUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_uid, :string
    add_index :users, :google_uid, unique: true, where: "google_uid IS NOT NULL"
  end
end
