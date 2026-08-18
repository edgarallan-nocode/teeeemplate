# frozen_string_literal: true

namespace :credentials do
  DEVELOPMENT_TEMPLATE = <<~YAML
    # Development credentials. The matching key lives at
    # config/credentials/development.key and is gitignored — it is generated
    # per-machine and is never shared.
    #
    # Edit with:  bin/rails credentials:edit --environment development
    #
    # These are placeholders. Drop in your Stripe *test* keys to exercise
    # billing locally.
    stripe:
      publishable_key: pk_test_replace_me
      secret_key: sk_test_replace_me
      webhook_secret: whsec_replace_me

    sentry:
      dsn:
  YAML

  desc "Create config/credentials/development.yml.enc if it does not exist yet"
  task :bootstrap_development do
    require "active_support"
    require "active_support/encrypted_configuration"

    root       = Pathname.new(__dir__).join("..", "..").expand_path
    key_path   = root.join("config/credentials/development.key")
    enc_path   = root.join("config/credentials/development.yml.enc")

    if enc_path.exist? && key_path.exist?
      puts "credentials: development credentials already present"
      next
    end

    if enc_path.exist? && !key_path.exist?
      abort <<~MSG
        credentials: config/credentials/development.yml.enc exists but
        config/credentials/development.key is missing, so it cannot be read.

        Either restore the key or delete the .enc file and re-run bin/setup to
        generate fresh development credentials.
      MSG
    end

    enc_path.dirname.mkpath

    config = ActiveSupport::EncryptedConfiguration.new(
      config_path: enc_path,
      key_path: key_path,
      env_key: "RAILS_MASTER_KEY",
      raise_if_missing_key: true
    )
    key_path.binwrite(ActiveSupport::EncryptedConfiguration.generate_key)
    key_path.chmod(0o600)
    config.write(DEVELOPMENT_TEMPLATE)

    puts "credentials: generated config/credentials/development.yml.enc"
    puts "credentials: generated config/credentials/development.key (gitignored)"
  end
end
