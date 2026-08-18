# frozen_string_literal: true

# == Schema Information
#
# Table name: memberships
#
#  id         :bigint           not null, primary key
#  role       :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_memberships_on_team_id              (team_id)
#  index_memberships_on_team_id_and_role     (team_id,role)
#  index_memberships_on_user_id              (user_id)
#  index_memberships_on_user_id_and_team_id  (user_id,team_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :membership do
    user
    team
    role { :member }

    trait(:owner)  { role { :owner } }
    trait(:admin)  { role { :admin } }
    trait(:member) { role { :member } }
  end
end
