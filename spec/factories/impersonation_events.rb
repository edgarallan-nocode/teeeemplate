# frozen_string_literal: true

# == Schema Information
#
# Table name: impersonation_events
#
#  id         :bigint           not null, primary key
#  ended_at   :datetime
#  ip_address :string
#  reason     :string
#  started_at :datetime         not null
#  user_agent :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  admin_id   :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_impersonation_events_on_admin_id                 (admin_id)
#  index_impersonation_events_on_admin_id_and_started_at  (admin_id,started_at)
#  index_impersonation_events_on_ended_at                 (ended_at)
#  index_impersonation_events_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (admin_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :impersonation_event do
    admin { association :user, :admin }
    user
    started_at { Time.current }

    trait :ended do
      ended_at { Time.current }
    end
  end
end
