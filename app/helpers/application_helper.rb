# frozen_string_literal: true

module ApplicationHelper
  # Maps a subscription status to a badge variant, so status colour is decided
  # in one place rather than in each view that happens to render one.
  def subscription_badge(subscription)
    return tag.span("No subscription", class: "badge badge--quiet") if subscription.nil?

    variant =
      case subscription.status
      when "active", "trialing" then "positive"
      when "past_due", "unpaid", "paused" then "caution"
      when "canceled", "incomplete_expired" then "critical"
      else "quiet"
      end

    tag.span(subscription.status_label, class: "badge badge--#{variant}")
  end

  def role_badge(membership)
    variant = membership.owner? ? "accent" : "quiet"
    tag.span(membership.role_label, class: "badge badge--#{variant}")
  end

  # Short, unambiguous timestamps. Absolute rather than "3 days ago", because
  # support and billing questions need the actual date.
  def short_date(time)
    return "—" if time.blank?

    tag.time(time.to_date.to_fs(:long), datetime: time.iso8601, title: time.iso8601)
  end

  def short_datetime(time)
    return "—" if time.blank?

    tag.time(time.strftime("%-d %b %Y, %H:%M"), datetime: time.iso8601)
  end

  # The record to ask a billing policy about, for a team that may not have a
  # subscription yet.
  #
  # Built with team_id rather than team: assigning the association would push
  # this unsaved placeholder into the team's has_one cache via inverse_of, and
  # a later read of team.subscription would return the blank record.
  def billing_subject_for(team)
    team.subscription || Subscription.new(team_id: team.id)
  end

  def page_title(title, description: nil, &actions)
    render "shared/page_header", title: title, description: description, actions: actions
  end
end
