---
name: rails-saas-conventions
description: >
  Architectural rules for this Rails SaaS application — tenant scoping, Pundit,
  service objects, Turbo/Stimulus, SASS, Stripe, credentials, AWS via IAM roles,
  testing, and deployment. Read this before writing or modifying any code in
  this repository.
---

# Working in this codebase

This is a standard Rails 8 application with a small number of strong opinions.
It is not a framework. Almost everything you need is ordinary Rails, and the
right answer is usually the plainest one.

## Before you write anything

**Read the neighbours first.** Open the two or three files closest to what you
are about to change and match them — their naming, their comment density, their
structure. A correct change in the wrong idiom still makes the codebase worse.

**Prefer the simplest standard Rails implementation.** If the answer is a scope,
write a scope. Do not reach for a service object, a query object, a concern, or
a gem until the plain version has actually failed. Abstractions here earn their
place by solving a recurring problem that already exists — not one you expect.

**Do not add dependencies casually.** This application deliberately hand-rolls
pagination rather than take a gem with a moving API. Apply the same standard.

---

## 1. Tenant scoping — the rule everything else rests on

Every tenant-owned model includes `TenantScoped` (`app/models/concerns/`), which
gives it `belongs_to :team` and a presence validation.

**Every query starts from the team.**

```ruby
# NEVER
Project.find(params[:id])
Project.where(name: params[:q])

# ALWAYS
current_team.projects.find(params[:id])
current_team.projects.search(params[:q])
```

A record belonging to another team is then *not found*, not *forbidden*. Rails
raises `RecordNotFound` and `ApplicationController` renders **404**. This is
deliberate: a 403 would confirm the record exists.

Do not "fix" this by adding a `record.team == Current.team` check inside a
policy. If a policy needs that check, the controller scoped its query wrongly —
fix the controller.

There is **no `default_scope`** doing this invisibly, and there must not be. The
scoping is visible in every controller because that is what makes it auditable.

### When you add a tenant-owned model

1. `include TenantScoped`
2. Add a `team` reference with a foreign key and an index in the migration
3. Write a policy
4. Apply the shared example:

```ruby
it_behaves_like "a tenant-isolated resource" do
  let(:factory) { :thing }
  let(:member_path) { ->(record) { thing_path(record) } }
  let(:collection_path) { things_path }
  let(:update_params) { { thing: { name: "Hijacked" } } }
end
```

`spec/models/tenant_scoping_spec.rb` fails the build if a model has a `team_id`
and forgot the concern. Do not add a table to its exempt list without a comment
explaining why it is not tenant-owned.

### Current

`Current.user`, `Current.team`, `Current.membership`, `Current.true_user`. Set
once per request in `ApplicationController`. `true_user` differs from `user`
only during admin impersonation, and every audit record captures both.

Do not read `Current` from a model to make a decision the caller should have
passed in. `TenantScoped` uses it to *default* `team` on create, and that is the
extent of it.

---

## 2. Pundit

> **Tenant scoping** decides *which records exist for you.*
> **Pundit** decides *what you may do with them.*

Both always apply. `ApplicationController` verifies it: every `index` must call
`policy_scope`, every other action must call `authorize`. A controller that
legitimately does neither says so with `skip_authorization` / `skip_policy_scope`
— which is greppable, unlike silence.

**All role logic lives in policies.** If a controller or a view is asking
`membership.owner?` directly, that check has escaped its policy. Views ask
`policy(record).update?`, never `Current.membership.admin?`.

Roles are ordered (`member: 0, admin: 1, owner: 2`) so policies compare rather
than enumerate:

```ruby
def update? = admin_or_above?     # not: membership.admin? || membership.owner?
```

Money and destruction are owners-only, and additionally blocked while
impersonating:

```ruby
def checkout? = owner? && !impersonating?
```

---

## 3. Service objects

A service is for a **multi-step operation** that touches more than one model or
talks to the outside world. `record.update!(name: x)` is not a service; leave it
in the controller.

```ruby
class Teams::InviteMember < ApplicationService
  def initialize(team:, email:, role:, invited_by:) = ...

  def call
    return failure_from(invitation) unless invitation.save
    success(invitation)
  end
end
```

- Always `.call(**kwargs)`, always returns `Result` (`success?`, `value`, `error`)
- Failures are returned, not raised — controllers re-render with the message
- Invariants that must *always* hold (a team keeps an owner) belong on the
  **model**, not in the service, so every caller inherits them
- Namespace by domain: `Teams::`, `Billing::`, `Users::`, `Admin::`

Do not add a step DSL, dry-rb, or a result monad. `ApplicationService` is
twenty lines and should stay that way.

---

## 4. Turbo and Stimulus

Server-rendered ERB is the default. Reach for JavaScript last.

- **Turbo Drive** for navigation — you get it for free, do not fight it
- **Turbo Frames** for partial updates and the modal
- **Turbo Streams** for flash messages and list updates
- **Stimulus** for browser behaviour that genuinely needs it

Seven controllers exist: `dropdown`, `modal`, `tabs`, `clipboard`, `autosubmit`,
`toggle`, `flash`. **Check whether one of them already does the job** before
writing a new one. Register new controllers explicitly in
`app/javascript/controllers/index.js` — there is no auto-loading, on purpose.

**Never**: React, Vue, a SPA router, client-side templating, or a component
framework. If a feature seems to need one, it almost certainly needs a Turbo
Frame.

esbuild is there so a genuine npm dependency can be added when one is warranted.
That is a considered decision, not a default.

---

## 5. Styling — SASS only

```
abstracts/   tokens, mixins, breakpoints — emit no CSS themselves
base/        element defaults
components/  reusable pieces, named for what they are
pages/       the few things truly specific to one screen
```

- Add new partials to `application.scss` by hand. The import order is part of
  the design; there is no glob
- Use the tokens in `abstracts/_variables.scss`. Do not hard-code a colour, a
  font size, a font weight, or a spacing value
- **Type is one family: Lexend Deca**, self-hosted in `app/assets/fonts` and
  declared in `base/_fonts.scss`. Display and body differ by weight, size and
  tracking, not by typeface. Do not add a second family, and do not load fonts
  from a CDN — a third-party font request is render-blocking and sends visitor
  IPs to that provider
- Semantic class names (`.table__primary`, `.btn--ghost`), never utility soup
- **No Tailwind, ever**

The visual direction is editorial: strong type, generous whitespace, hairline
rules. **No border radius, no gradients, no decorative shadows.** The single
exception is the dropdown menu's shadow, which separates a floating layer from
the page rather than decorating a static box. Do not add more.

Dark mode is handled entirely by redefining tokens under
`prefers-color-scheme: dark`. Components should never need a dark-mode branch.

---

## 6. Stripe

**Billing belongs to the team, never to a user.** Subscriptions are **per seat**:
the Stripe quantity always equals the team's member count.

### Non-negotiables

1. **Verify the signature.** `Stripe::Webhook.construct_event`. Invalid ⇒ 400,
   and nothing else runs.
2. **Be idempotent.** Every event id is inserted into `stripe_events`, which has
   a unique index. A duplicate insert means a redelivery — return 200 and stop.
   Stripe guarantees at-least-once delivery; duplicates are normal, not errors.
3. **Do the work in a job.** The webhook controller records and enqueues. That
   is all it does.
4. **`Billing::ProcessStripeEvent` is the only writer of local subscription
   state.** Nothing else updates a `Subscription` from Stripe data.
5. **Never trust a redirect.** A successful return from Checkout means the
   browser came back, nothing more. The webhook is what makes a subscription
   real.
6. **Never call Stripe on the request path** to answer "is this team paid?".
   `Team#subscription_active?` reads local state.
7. **Pass an idempotency key** on every mutating Stripe call, so a retried job
   cannot double-charge.

### Handlers must be re-runnable

Set absolute state from the payload. Never increment, toggle, or apply a delta —
the job will be retried.

Price ids come from credentials via `Plan#stripe_price_id`, never from
`config/plans.yml` directly, so test and live ids can differ per environment.

---

## 7. Credentials and secrets

| Goes in | What |
|---|---|
| **Rails credentials** | Stripe keys and webhook secret, Stripe price ids, Sentry DSN |
| **Environment variables** | `DATABASE_URL`, `REDIS_URL`, `APP_HOST`, ports, thread counts, AWS region and bucket |
| **Nowhere** | AWS access keys |

```bash
bin/rails credentials:edit --environment development
bin/rails credentials:edit --environment production
```

- Never commit a `.key` file. They are gitignored; keep it that way
- Never put a secret in `.env.example`, a spec, a seed, or a comment
- Read with `Rails.application.credentials.dig(:stripe, :secret_key)`

### AWS uses IAM instance roles

SES and S3 resolve credentials from the **EC2 instance role**. There are no
access keys in this repository and none should ever be added — not to
`config/storage.yml`, not to credentials, not to the environment.

---

## 8. Background jobs

Active Job on Sidekiq. Queues: `critical`, `default`, `mailers`, `low`.

**Every job must be safe to run more than once.** Retries are expected, so a job
reads its target state from the database and reconciles, rather than applying a
change blindly. `Billing::SyncSeats` is the model to copy: it compares the
member count to the stored quantity and no-ops when they match.

All mail is `deliver_later`. Nothing in a request waits on SES.

---

## 9. Testing

RSpec, Capybara, FactoryBot, shoulda-matchers, WebMock. Outbound HTTP is blocked,
so a spec that accidentally reaches Stripe fails loudly.

```
spec/models      validations and invariants
spec/policies    every policy, every role, permitted AND forbidden
spec/requests    controllers end to end, including isolation
spec/services    multi-step behaviour, including idempotency
spec/system      user-facing flows
```

Expectations for new work:

- A new tenant-owned resource gets the isolation shared example. Not optional
- A new policy gets a spec **per role**, asserting both the allowed and the
  denied case. A policy spec that only proves the happy path proves nothing
- A new service that touches Stripe gets an idempotency spec — call it twice,
  assert one effect
- Webhook specs sign payloads with Stripe's real algorithm
  (`spec/support/stripe_helpers.rb`). Never stub signature verification away;
  a stub would keep passing if the check were deleted

---

## 10. Quality gates

```bash
bin/lint          # RuboCop, Brakeman, bundler-audit
bin/lint --fix    # autocorrect first
bin/ci            # everything CI runs
```

`.rubocop.yml` is the source of truth — editor plugins only mirror it. Its base
is `rubocop-rails-omakase`, and every deviation carries a comment saying why.

**Never silence a security warning without a written reason.** Do not add a
Brakeman ignore, a `rubocop:disable`, or a bundler-audit ignore without a comment
on the same line or directly above explaining the specific reason it is safe.
Prefer fixing the code.

---

## 11. Deployment

Hatchbox on AWS EC2. Puma, PostgreSQL, Redis, Sidekiq, SES, S3.

**No Docker. No Kamal. No Compose.** Do not add a `Dockerfile`, and do not
suggest containerising as a solution to anything.

Production needs `RAILS_MASTER_KEY` supplied externally and nothing else secret.
Everything else is in the environment variable table in `README.md` — if you add
a required variable, add it there and to `.env.example` in the same change.

---

## Quick reference — hard NOs

| Do not | Instead |
|---|---|
| `Model.find(params[:id])` on tenant data | `current_team.things.find(...)` |
| A `default_scope` for tenancy | Explicit scoping in the controller |
| A role check in a controller or view | A Pundit policy method |
| `record.team == Current.team` in a policy | Fix the controller's query |
| Trusting a Stripe redirect | Wait for the webhook |
| Calling Stripe to check entitlement | `team.subscription_active?` |
| An AWS access key anywhere | The EC2 instance IAM role |
| Tailwind, utility classes | The SASS design system and its tokens |
| React, Vue, a SPA | Turbo Frames and Streams |
| Docker, Kamal | Hatchbox |
| An admin framework | Plain Rails under `Admin::` |
| Silencing a scanner | Fixing the code, or a written reason |
| A gem for something small | Write the twenty lines |
