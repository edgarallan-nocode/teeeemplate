# frozen_string_literal: true

module Public
  class PagesController < BaseController
    def home
      redirect_to dashboard_path if user_signed_in?
    end

    def pricing
      @plans = Plan.all
    end

    def terms; end

    def privacy; end
  end
end
