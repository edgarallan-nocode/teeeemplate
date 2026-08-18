# frozen_string_literal: true

# Base for service objects.
#
# Services exist for multi-step operations that touch more than one model or
# have to coordinate with the outside world — inviting a member, processing a
# Stripe event, deleting an account. A one-line `record.update!` is not a
# service; leave it in the controller.
#
# Every service is called the same way and returns the same thing:
#
#   result = Teams::InviteMember.call(team:, email:, role:, invited_by:)
#   if result.success?
#     result.value
#   else
#     result.error
#   end
#
# Deliberately tiny. No dry-rb, no step DSL, no result monads beyond this.
class ApplicationService
  Result = Struct.new(:success, :value, :error, keyword_init: true) do
    def success? = success
    def failure? = !success
  end

  def self.call(...) = new(...).call

  private

  def success(value = nil) = Result.new(success: true, value: value)

  def failure(error, value: nil) = Result.new(success: false, value: value, error: error)

  # Turns a failed Active Record save into a Result rather than an exception,
  # so controllers can re-render a form with the record's own errors attached.
  def failure_from(record)
    failure(record.errors.full_messages.to_sentence, value: record)
  end
end
