# frozen_string_literal: true

# The design system, rendered from the system itself.
#
# This page renders through the application layout and `application.scss`, and
# its interactive pieces are driven by the real Stimulus controllers. Nothing
# here carries a copy of a token or a component rule, so the guide cannot drift
# from what it documents — change a component and this page changes with it.
#
# Everything it needs to say is in SKILL.md §5 and STYLE.md §9. This is those
# two sections made visible.
class StyleguideController < ApplicationController
  skip_team_requirement!

  skip_before_action :authenticate_user!
  before_action :require_styleguide_access

  def show
    # No records are involved, so neither gate has anything to decide. Said out
    # loud rather than left silent, because ApplicationController verifies that
    # one of them ran.
    skip_authorization
  end

  private

  # Open in development and test, where it is a working tool.
  #
  # In production it is platform-admin only, and anyone else gets 404 rather
  # than 403 — the same answer the rest of the application gives for something
  # that is not theirs to see, and it does not confirm the page exists.
  def require_styleguide_access
    return if Rails.env.local?
    raise ActiveRecord::RecordNotFound unless Current.user&.admin?
  end
end
