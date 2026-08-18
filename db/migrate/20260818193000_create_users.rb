# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Devise :database_authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      # Devise :recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      # Devise :rememberable
      t.datetime :remember_created_at

      # Devise :confirmable
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email

      # Devise :trackable
      t.integer :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip

      # Profile
      t.string :first_name
      t.string :last_name

      # Platform administration. Deliberately separate from team roles: this is
      # staff access to the whole install, not a role within any one team.
      t.boolean :admin, null: false, default: false

      # Remembers which team the user was last working in, so a new session
      # lands where the previous one left off.
      t.bigint :last_team_id

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token, unique: true
    add_index :users, :last_team_id
    add_index :users, :admin, where: "admin"
  end
end
