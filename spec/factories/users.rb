# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  admin                  :boolean          default(FALSE), not null
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  first_name             :string
#  last_name              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  last_team_id           :bigint
#
# Indexes
#
#  index_users_on_admin                 (admin) WHERE admin
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_last_team_id          (last_team_id)
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (last_team_id => teams.id) ON DELETE => nullify
#
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password1234" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }

    trait :admin do
      admin { true }
    end

    # A user who already owns a team, for specs that need a ready tenant.
    trait :with_team do
      transient { team_name { nil } }

      after(:create) do |user, evaluator|
        team = create(:team, name: evaluator.team_name || Faker::Company.unique.name)
        create(:membership, user: user, team: team, role: :owner)
        user.update_column(:last_team_id, team.id)
      end
    end
  end
end
