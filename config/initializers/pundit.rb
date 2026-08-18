# frozen_string_literal: true

# Pundit resolves policies from the record's class. Nothing to configure here
# beyond documenting the rule the whole application follows:
#
#   Tenant scoping decides WHICH records exist for the current user.
#   Pundit decides WHAT the current user may do with them.
#
# Both always apply. A Pundit check is never a substitute for scoping a query
# to Current.team, and scoping is never a substitute for a policy check.
