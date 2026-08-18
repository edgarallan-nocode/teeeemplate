# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id            :bigint           not null, primary key
#  archived_at   :datetime
#  description   :text
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :bigint
#  team_id       :bigint           not null
#
# Indexes
#
#  index_projects_on_created_by_id           (created_by_id)
#  index_projects_on_team_id                 (team_id)
#  index_projects_on_team_id_and_created_at  (team_id,created_at)
#  index_projects_on_team_id_and_name        (team_id,name)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#
FactoryBot.define do
  factory :project do
    team
    sequence(:name) { |n| "Project #{n}" }
    description { Faker::Company.catch_phrase }

    trait :archived do
      archived_at { Time.current }
    end
  end
end
