# frozen_string_literal: true

module Billing
  class SubscriptionsController < ApplicationController
    # Support staff can look at a customer's billing page but must never be able
    # to move their money. The policies enforce it too; this is the second lock.
    before_action :block_while_impersonating!, only: %i[checkout portal]

    def show
      @subscription = current_team.subscription
      authorize billing_subject, :show?

      @plans = Plan.all
      @seat_count = current_team.seat_count
    end

    def checkout
      authorize billing_subject, :checkout?

      result = Billing::CreateCheckoutSession.call(
        team: current_team,
        plan: Plan.find(params[:plan]),
        success_url: billing_checkout_success_url,
        cancel_url: billing_checkout_cancel_url
      )

      if result.success?
        redirect_to result.value.url, allow_other_host: true, status: :see_other
      else
        redirect_to billing_subscription_path, alert: result.error
      end
    end

    def portal
      authorize billing_subject, :portal?

      result = Billing::CreatePortalSession.call(
        team: current_team, return_url: billing_subscription_url
      )

      if result.success?
        redirect_to result.value.url, allow_other_host: true, status: :see_other
      else
        redirect_to billing_subscription_path, alert: result.error
      end
    end

    # Stripe sends the browser back here after checkout. This is NOT proof of
    # payment — anyone can visit this URL. The page says the subscription is
    # being confirmed, and the webhook is what actually activates it.
    def checkout_success
      @subscription = current_team.subscription
      authorize billing_subject, :show?
    end

    def checkout_cancel
      authorize billing_subject, :show?

      redirect_to billing_subscription_path, notice: "Checkout canceled. Nothing was charged."
    end

    private

    # The record a billing policy is asked about.
    #
    # The placeholder is built with `team_id:` rather than `team:` on purpose.
    # Assigning the association would write the unsaved record into the team's
    # has_one cache through inverse_of, so a later `current_team.subscription`
    # would return this blank object instead of the real one.
    def billing_subject
      @subscription || Subscription.new(team_id: current_team.id)
    end
  end
end
