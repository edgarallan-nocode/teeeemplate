# frozen_string_literal: true

redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# Job arguments must be simple JSON-native types. This turns "it worked in
# development and blew up in production" serialization bugs into a loud failure
# at enqueue time instead.
Sidekiq.strict_args!
