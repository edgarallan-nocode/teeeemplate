# frozen_string_literal: true

require "sidekiq/web"

Rails.application.routes.draw do
  # --- Authentication ------------------------------------------------------
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
    passwords: "users/passwords"
  }

  # --- Public marketing shell ---------------------------------------------
  scope module: :public do
    root "pages#home"
    get "pricing", to: "pages#pricing"
    get "terms",   to: "pages#terms"
    get "privacy", to: "pages#privacy"
  end

  # --- Signed-in application ----------------------------------------------
  get "dashboard", to: "dashboard#show", as: :dashboard

  resources :projects

  resources :teams, only: %i[new create edit update destroy] do
    resource :switch, only: :create, module: :teams, as: :switch
    resources :members, only: %i[index update destroy], module: :teams
    resources :invitations, only: %i[index create destroy], module: :teams
    resource :leave, only: :create, module: :teams, as: :leave
  end

  # Public invitation acceptance. Reached from an email, so it must work for a
  # signed-out user and for one who does not yet have an account.
  resources :invitations, only: :show, param: :token do
    member { post :accept }
  end

  # --- Account -------------------------------------------------------------
  resource :account, only: %i[show update destroy], controller: :account do
    get :confirm_delete
  end

  # --- Billing -------------------------------------------------------------
  namespace :billing do
    resource :subscription, only: %i[show], controller: :subscriptions do
      post :checkout
      post :portal
    end
    get "checkout/success", to: "subscriptions#checkout_success", as: :checkout_success
    get "checkout/cancel",  to: "subscriptions#checkout_cancel",  as: :checkout_cancel

    # Stripe posts here. No authentication, no CSRF, signature verified instead.
    post "webhooks", to: "webhooks#create"
  end

  # --- Platform administration --------------------------------------------
  namespace :admin do
    root "dashboard#show"
    resources :users, only: %i[index show]
    resources :teams, only: %i[index show]
    resources :subscriptions, only: :index
    resources :impersonations, only: :create
    delete "impersonations", to: "impersonations#destroy", as: :stop_impersonation

    # Sidekiq's UI sits behind the same admin gate as everything else here.
    mount Sidekiq::Web => "/sidekiq"
  end

  # --- Development-only -----------------------------------------------------
  mount LetterOpenerWeb::Engine, at: "/dev/letter_opener" if Rails.env.development?

  # --- Health --------------------------------------------------------------
  get "up" => "rails/health#show", as: :rails_health_check
end
