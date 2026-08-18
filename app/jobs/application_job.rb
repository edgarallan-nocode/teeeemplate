# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # A job whose arguments no longer resolve (the record was deleted) will never
  # succeed. Retrying it just fills the queue.
  discard_on ActiveJob::DeserializationError

  # Transient infrastructure failures are worth retrying; everything else should
  # surface in Sentry rather than being silently swallowed.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
  retry_on Redis::BaseConnectionError, wait: :polynomially_longer, attempts: 5

  # Every job in this application must be safe to run more than once. Retries
  # are expected, so jobs recompute their target state from the database rather
  # than applying a delta.
end
