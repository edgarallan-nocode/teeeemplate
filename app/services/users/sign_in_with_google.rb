# frozen_string_literal: true

module Users
  # What a Google callback means for this application's users.
  #
  # Takes the OmniAuth auth hash Google sent back and answers with a user, in one
  # of three ways:
  #
  #   * signed in, the Google account connects to the signed-in user
  #   * signed out and the Google account is known, that user
  #   * signed out and it is not, a new user carrying the Google name and email
  #
  # The fourth case refuses. A signed-out Google sign-in whose email matches an
  # existing account that has *not* connected Google does not link them. Email
  # addresses here are unverified (SKILL.md §2a), so the existing account is
  # only a claim on that address — and anybody could have made it, kept the
  # password, and be waiting for the real owner to arrive through Google and
  # start working inside it. The real owner signs in with their password and
  # connects Google from their account page; the connect branch above is the
  # only way an existing account gains a google_uid.
  class SignInWithGoogle < ApplicationService
    def initialize(auth:, current_user: nil)
      @auth = auth
      @current_user = current_user
    end

    def call
      return failure("Google did not tell us who you are. Try again.") if uid.blank?
      return connect if @current_user

      user = User.find_by(google_uid: uid)
      return success(user) if user
      return failure(existing_account_message) if User.exists?(email: email)

      register
    end

    private

    def uid = @auth.uid.to_s
    def email = @auth.info.email.to_s

    def connect
      if User.where.not(id: @current_user.id).exists?(google_uid: uid)
        return failure("That Google account is already connected to a different account.")
      end

      @current_user.update!(google_uid: uid)
      success(@current_user)
    end

    # A password is required by :validatable and nobody will ever know this one.
    # Setting a real one later goes through "Forgot your password?", which is
    # the same path any user takes to a password they have lost.
    def register
      user = User.new(
        email: email,
        first_name: @auth.info.first_name.to_s.first(100),
        last_name: @auth.info.last_name.to_s.first(100),
        google_uid: uid,
        password: Devise.friendly_token
      )

      user.save ? success(user) : failure_from(user)
    end

    def existing_account_message
      "An account already exists for #{email}. Sign in with your password, " \
      "then connect Google from your account page."
    end
  end
end
