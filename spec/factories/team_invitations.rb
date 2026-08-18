# frozen_string_literal: true

# == Schema Information
#
# Table name: team_invitations
#
#  id             :bigint           not null, primary key
#  accepted_at    :datetime
#  email          :string           not null
#  expires_at     :datetime         not null
#  role           :integer          default(0), not null
#  token          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  accepted_by_id :bigint
#  invited_by_id  :bigint           not null
#  team_id        :bigint           not null
#
# Indexes
#
#  index_team_invitations_on_accepted_by_id          (accepted_by_id)
#  index_team_invitations_on_invited_by_id           (invited_by_id)
#  index_team_invitations_on_team_id                 (team_id)
#  index_team_invitations_on_token                   (token) UNIQUE
#  index_team_invitations_pending_on_team_and_email  (team_id,email) UNIQUE WHERE (accepted_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (accepted_by_id => users.id)
#  fk_rails_...  (invited_by_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#
FactoryBot.define do
  factory :team_invitation do
    team
    invited_by { association :user }
    sequence(:email) { |n| "invitee#{n}@example.com" }
    role { :member }

    trait :accepted do
      accepted_at { Time.current }
      accepted_by { association :user }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
