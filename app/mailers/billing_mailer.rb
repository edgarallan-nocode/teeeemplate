# frozen_string_literal: true

class BillingMailer < ApplicationMailer
  def payment_failed(team)
    @team = team
    @subscription = team.subscription

    mail to: owner_emails(@team),
         subject: "Payment failed for #{@team.name}"
  end

  def subscription_canceled(team)
    @team = team
    @subscription = team.subscription

    mail to: owner_emails(@team),
         subject: "Your #{@team.name} subscription has been canceled"
  end

  def trial_ending(team)
    @team = team
    @subscription = team.subscription
    @ends_at = @subscription&.trial_ends_at

    mail to: owner_emails(@team),
         subject: "Your #{@team.name} trial ends soon"
  end

  private

  # Billing belongs to the team, so billing mail goes to the team's owners
  # rather than to whoever happened to trigger the change.
  def owner_emails(team) = team.owners.pluck(:email)
end
