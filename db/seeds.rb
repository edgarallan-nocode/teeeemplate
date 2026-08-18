# frozen_string_literal: true

# Development seed data.
#
# Idempotent — run it as many times as you like. The point is to make tenant
# isolation *visible*: two teams, two owners, and one person who belongs to
# both. Sign in as different users and watch the data change.

if Rails.env.production?
  abort "Refusing to seed production. Delete this guard only if you mean it."
end

PASSWORD = "password1234"

def upsert_user!(email, first_name:, last_name:, admin: false)
  User.find_or_create_by!(email: email) do |user|
    user.password = PASSWORD
    user.first_name = first_name
    user.last_name = last_name
    user.admin = admin
    user.confirmed_at = Time.current
  end
end

def upsert_team!(name, slug:)
  Team.find_or_create_by!(slug: slug) { |team| team.name = name }
end

def upsert_membership!(user, team, role)
  Membership.find_or_create_by!(user: user, team: team) { |m| m.role = role }
end

# --- People ----------------------------------------------------------------
admin  = upsert_user!("admin@example.com",  first_name: "Ada",   last_name: "Admin", admin: true)
alice  = upsert_user!("alice@example.com",  first_name: "Alice", last_name: "Owner")
bob    = upsert_user!("bob@example.com",    first_name: "Bob",   last_name: "Owner")
carol  = upsert_user!("carol@example.com",  first_name: "Carol", last_name: "Member")

# --- Teams -----------------------------------------------------------------
northwind = upsert_team!("Northwind Traders", slug: "northwind")
contoso   = upsert_team!("Contoso Industries", slug: "contoso")

upsert_membership!(alice, northwind, :owner)
upsert_membership!(carol, northwind, :admin)
upsert_membership!(bob,   contoso,   :owner)
# Carol belongs to both teams — switch between them to see scoping at work.
upsert_membership!(carol, contoso,   :member)

alice.update_column(:last_team_id, northwind.id)
bob.update_column(:last_team_id, contoso.id)
carol.update_column(:last_team_id, northwind.id)

# --- Tenant data -----------------------------------------------------------
{
  northwind => [ "Q3 catalogue", "Supplier portal", "Warehouse rewrite" ],
  contoso   => [ "Widget redesign", "Pricing experiment" ]
}.each do |team, names|
  names.each do |name|
    team.projects.find_or_create_by!(name: name) do |project|
      project.description = "Seed data for #{team.name}."
      project.created_by = team.owners.first
    end
  end
end

# --- A pending invitation --------------------------------------------------
northwind.invitations.find_or_create_by!(email: "dana@example.com", accepted_at: nil) do |invitation|
  invitation.role = :member
  invitation.invited_by = alice
end

# --- Billing ---------------------------------------------------------------
# A local subscription record with no Stripe counterpart, so the paid-team UI
# can be seen without touching Stripe. Use `stripe listen` for the real flow.
Subscription.find_or_create_by!(team: northwind) do |subscription|
  subscription.stripe_subscription_id = "sub_seed_northwind"
  subscription.stripe_subscription_item_id = "si_seed_northwind"
  subscription.stripe_price_id = "price_seed_starter"
  subscription.plan_key = "starter"
  subscription.status = "active"
  subscription.quantity = northwind.seat_count
  subscription.current_period_end = 30.days.from_now
end

puts <<~SUMMARY

  Seeded. Every account uses the password: #{PASSWORD}

    admin@example.com   platform admin, no team
    alice@example.com   owner of Northwind Traders (subscribed)
    bob@example.com     owner of Contoso Industries (no subscription)
    carol@example.com   admin in Northwind, member in Contoso — switch teams to
                        watch the project list change

  Sign in at http://localhost:3000/users/sign_in
  Read development mail at http://localhost:3000/dev/letter_opener

SUMMARY
