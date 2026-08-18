# Teeeemplate

An opinionated Ruby on Rails SaaS starter. Authentication, team multi-tenancy,
per-seat Stripe billing, background jobs, a design system and a platform admin
area — assembled once so the next project starts at the interesting part.

It is a Rails application first and a template second. There is no framework on
top of Rails, no DSL to learn, and no magic that has to be understood before you
can read a controller.

```
Ruby 3.4  ·  Rails 8.1  ·  PostgreSQL  ·  Redis  ·  Hotwire  ·  esbuild  ·  SASS
```

## Quickstart

```bash
bin/setup
```

That checks your Ruby and Node versions, installs dependencies, generates
development credentials, prepares the database, seeds it, and builds the assets.
Then:

```bash
bin/dev
```

Open <http://localhost:3000> and sign in with any seeded account — the password
for all of them is `password1234`:

| Account | What it shows you |
|---|---|
| `alice@example.com` | Owner of Northwind Traders, with a subscription |
| `bob@example.com` | Owner of Contoso Industries, no subscription |
| `carol@example.com` | Admin in one team, member in another — switch teams to watch the data change |
| `admin@example.com` | Platform admin. Visit `/admin` |

Development mail is captured at <http://localhost:3000/dev/letter_opener>.

### Commands

| Command | Does |
|---|---|
| `bin/setup` | Prepare a development environment. Safe to re-run |
| `bin/dev` | Web server, JS watcher, CSS watcher, Sidekiq |
| `bin/test` | RSpec. Arguments pass through: `bin/test spec/policies` |
| `bin/lint` | RuboCop, Brakeman, bundler-audit. `--fix` to autocorrect |
| `bin/ci` | Everything CI runs, in the same order |

## The one rule that matters

Every record belongs to a team, and **every query starts from the team**:

```ruby
# never
Project.find(params[:id])

# always
current_team.projects.find(params[:id])
```

A record belonging to another team is therefore not *forbidden* — it does not
exist for this request. `find` raises `RecordNotFound` and Rails renders 404.
That is both the honest answer and the safe one: a 403 would confirm the record
exists.

Pundit runs on top of this, answering a different question:

> **Tenant scoping** decides *which records exist for you.*
> **Pundit** decides *what you may do with them.*

Both always apply. Neither substitutes for the other. `spec/models/tenant_scoping_spec.rb`
fails the build if a model gains a `team_id` without including `TenantScoped`,
and `spec/support/shared_examples/tenant_isolation.rb` is applied to every
tenant-owned resource.

## Architecture

```
app/
  controllers/   HTTP only. Thin. Start every query from current_team
  models/        Records, validations, and invariants that must always hold
  policies/      Pundit. All role logic lives here and nowhere else
  services/      Multi-step operations. Return a Result, never raise for flow
  queries/       Reads too involved for a scope
  jobs/          Sidekiq. Every job is safe to run twice
  mailers/       HTML and plain text, always delivered via Active Job
  views/         Server-rendered ERB. Turbo for navigation
  javascript/    Stimulus controllers, registered explicitly
  assets/stylesheets/  SASS design system
```

### Roles

A `Membership` gives a user a role in one team: `owner`, `admin`, or `member`.
The enum values are ordered (`member: 0, admin: 1, owner: 2`) so policies can
ask `membership.at_least?(:admin)` instead of listing role names.

A team always has at least one owner. That invariant is enforced on the model,
so it holds no matter which service, console session, or future controller
tries to break it.

### Services

A service is for a multi-step operation that touches more than one model or
talks to the outside world. A one-line `record.update!` is not a service.

```ruby
result = Teams::InviteMember.call(team:, email:, role:, invited_by:)
result.success? ? result.value : result.error
```

`ApplicationService` is about twenty lines. There is no dry-rb, no step DSL, and
no result monad beyond `Result#success?`.

### Frontend

Server-rendered ERB, Turbo Drive for navigation, Turbo Frames and Streams for
partial updates, and seven Stimulus controllers for the rest: `dropdown`,
`modal`, `tabs`, `clipboard`, `autosubmit`, `toggle`, `flash`.

esbuild bundles the JavaScript, so a real npm package can be added when one
earns its place. There is no SPA, no React or Vue, and no Tailwind.

### Styling

SASS, organised as `abstracts/` (tokens, mixins, breakpoints), `base/`,
`components/`, and `pages/`. `application.scss` is a manifest and nothing else —
the import order is part of the design, so there is no glob.

The look is editorial: strong type, generous whitespace, hairline rules, no
border radius, no gradients, no decorative shadows. Change
`abstracts/_variables.scss` and the whole application follows, including dark
mode.

## Billing

Billing belongs to the **team**, never to a user. Subscriptions are **per seat**:
the Stripe quantity always equals the team's member count.

Plans are declared in `config/plans.yml`. That file is public — it drives the
pricing page — which is exactly why the Stripe price ids it names are resolved
from credentials at call time, so test and live ids can differ per environment.

### The webhook contract

`Billing::WebhooksController` is the thinnest controller in the application. It
does five things in a fixed order:

1. Verify the Stripe signature. Unsigned or tampered ⇒ **400**, nothing else runs.
2. Insert the event id. A unique index makes a redelivery fail — that failure is
   how a duplicate is recognised.
3. Enqueue `Billing::ProcessStripeEventJob`.
4. Return **200** quickly, so Stripe does not retry.
5. Never touch `Current`. There is no user and no team on this request.

`Billing::ProcessStripeEvent` is the only writer of local subscription state, so
`Team#subscription_active?` is a local read and no request ever depends on
Stripe being reachable.

**A browser redirect is never proof of payment.** `/billing/checkout/success` is
a URL anyone can visit; it says the subscription is being confirmed and waits for
the webhook to say otherwise.

### Testing billing locally

Put your Stripe **test** keys in development credentials:

```bash
bin/rails credentials:edit --environment development
```

```yaml
stripe:
  publishable_key: pk_test_…
  secret_key: sk_test_…
  webhook_secret: whsec_…     # printed by `stripe listen`
  prices:
    starter_monthly: price_…
    pro_monthly: price_…
```

Then forward webhooks:

```bash
stripe listen --forward-to localhost:3000/billing/webhooks
```

Run a checkout, confirm the subscription row appears only after the webhook
lands, then `stripe events resend <id>` and confirm nothing changes twice.

## Credentials and configuration

The split is deliberate:

| Goes in | What |
|---|---|
| **Rails credentials** (encrypted, committed) | Stripe keys, Stripe webhook secret, Stripe price ids, Sentry DSN |
| **Environment variables** (`.env.example`) | `DATABASE_URL`, `REDIS_URL`, `APP_HOST`, ports, thread counts, AWS region and bucket |
| **Nowhere** | AWS access keys — see below |

Credentials are per-environment: `config/credentials/development.yml.enc` and
`config/credentials/production.yml.enc`. Their `.key` files are gitignored and
must never be committed. Production supplies `RAILS_MASTER_KEY` externally.

```bash
bin/rails credentials:edit --environment production
```

### AWS

There are **no AWS access keys anywhere in this repository** — not in code, not
in credentials, not in the environment. On EC2 the AWS SDK resolves credentials
from the instance IAM role, for both SES and S3. The role needs:

- `ses:SendEmail`, `ses:SendRawEmail`
- `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` on your bucket

## Deployment

Hatchbox on AWS EC2. There is no Docker and no Kamal, by design.

**Process types**

```
web:    bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

**Deploy steps**

```
bundle install
npm ci
npm run build && npm run build:css
bin/rails db:migrate
bin/rails assets:precompile
```

**Required environment variables**

| Variable | Notes |
|---|---|
| `RAILS_MASTER_KEY` | Decrypts `config/credentials/production.yml.enc`. The only secret the platform must hold |
| `DATABASE_URL` | Provided by Hatchbox |
| `REDIS_URL` | Sidekiq, cache, and Action Cable |
| `APP_HOST` | e.g. `app.example.com`. Used for mail links and `config.hosts` |
| `APP_PROTOCOL` | `https` |
| `MAILER_FROM` | Must be a verified SES identity |
| `SUPPORT_EMAIL` | Shown in security-related email |
| `AWS_REGION` | For SES and S3 |
| `S3_BUCKET` | Active Storage bucket |
| `RAILS_MAX_THREADS`, `WEB_CONCURRENCY` | Puma sizing |
| `SIDEKIQ_CONCURRENCY` | Defaults to 10 in production |
| `SENTRY_ENVIRONMENT` | Optional. The DSN itself lives in credentials |

Sidekiq's web UI is mounted at `/admin/sidekiq`, behind the same platform-admin
gate as the rest of `/admin`.

## Admin area

`/admin` is plain Rails — no admin framework. It lists users, teams,
memberships and subscription state, with search, and it is gated on
`User#admin` alone. Platform admin is staff access to this installation; it is
unrelated to team roles and grants nothing inside a team you do not belong to.

**Impersonation** is available for support, with these rails:

- Only a platform admin can start one, and **an admin can never be impersonated**
- Every start and stop writes an `ImpersonationEvent` — who, whom, IP, and when
- A red banner is visible on every page for the duration
- Blocked while impersonating: checkout, the Stripe portal, account deletion,
  team deletion, and re-entering the admin area
- Authority is re-checked on every request, not just when it starts

## Testing

```bash
bin/test                      # everything
bin/test spec/policies        # one directory
bin/test spec/foo_spec.rb:42  # one example
```

RSpec with Capybara, FactoryBot, shoulda-matchers and WebMock. Outbound HTTP is
blocked by default, so a spec that accidentally calls Stripe fails loudly.

The specs worth reading before writing your own:

| File | Why |
|---|---|
| `spec/models/tenant_scoping_spec.rb` | Fails the build if a model gains `team_id` without `TenantScoped` |
| `spec/support/shared_examples/tenant_isolation.rb` | The isolation contract, applied per resource |
| `spec/requests/billing/webhooks_spec.rb` | Real Stripe signatures, replay and tamper rejection, idempotency |
| `spec/requests/admin/impersonation_spec.rb` | Every impersonation safety rail |
| `spec/policies/policies_spec.rb` | Every policy, per role, permitted **and** forbidden |

Webhook specs sign their payloads with Stripe's own algorithm rather than
stubbing verification away — they exercise the real `construct_event` path.

## Starting a real project from this

1. Rename the `Teeeemplate` module (`config/application.rb`, `config/*.yml`,
   `app/views/layouts/`, `README.md`).
2. Delete the example resource: the `Project` model, policy, controller, views,
   specs, and its migration.
3. Replace the placeholder copy in `app/views/public/pages/terms.html.erb` and
   `privacy.html.erb` with real text before taking a payment.
4. Set your own plans in `config/plans.yml` and your price ids in credentials.
5. Rotate credentials — generate fresh ones rather than inheriting these.
6. Point `abstracts/_variables.scss` at your own palette and type.

## What this deliberately does not have

No Docker, no Kamal, no Tailwind, no React or Vue, no SPA, no admin framework,
no service-object DSL, no pagination gem, and no `default_scope` doing tenancy
invisibly. Each of those was considered and left out. `SKILL.md` explains why,
and is written for coding agents as much as for people.
