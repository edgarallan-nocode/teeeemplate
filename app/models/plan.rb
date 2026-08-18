# frozen_string_literal: true

# A plan from config/plans.yml. Not an Active Record model — plans are
# configuration, not data, so they live in a file that reviews like code.
#
# Stripe price ids are resolved from credentials at call time so the same plan
# list works against test and live Stripe accounts.
class Plan
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :key, :string
  attribute :name, :string
  attribute :price_id, :string
  attribute :unit_amount, :integer
  attribute :interval, :string, default: "month"
  attribute :default, :boolean, default: false

  attr_accessor :features

  class << self
    def all
      @all ||= load_definitions.map do |definition|
        features = definition.delete("features") || []
        new(**definition.symbolize_keys).tap { |plan| plan.features = features }
      end.freeze
    end

    def find(key) = all.find { |plan| plan.key == key.to_s }

    def default = all.find(&:default) || all.first

    def keys = all.map(&:key)

    # Test suites reload plans after stubbing credentials.
    def reload! = (@all = nil)

    private

    def load_definitions
      YAML.load_file(Rails.root.join("config/plans.yml")).fetch("plans")
    end
  end

  # The Stripe price id for this plan, from credentials.
  def stripe_price_id
    Rails.application.credentials.dig(:stripe, :prices, price_id.to_sym)
  end

  def monthly_price
    format("$%.2f", unit_amount / 100.0)
  end

  def to_param = key
end
