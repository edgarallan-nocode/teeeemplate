# frozen_string_literal: true

# Base for query objects.
#
# A query object is for a read that is too involved to sit comfortably in a
# scope — multiple joins, conditional filters, ordering that depends on input.
# Simple filters stay as scopes on the model.
#
# Queries always receive an already-tenant-scoped relation. They narrow it; they
# never widen it, and they never start from `Model.all`.
class ApplicationQuery
  def self.call(...) = new(...).call

  private

  attr_reader :relation
end
