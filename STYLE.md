# Style guide

How code in this repository is *written*. Three documents divide the work and
they do not overlap:

| Document | Owns | Enforced by |
|---|---|---|
| [SKILL.md](SKILL.md) | Architecture — tenant scoping, Pundit, services, Stripe, secrets | Specs and review |
| [.rubocop.yml](.rubocop.yml) | Mechanical formatting — indentation, spacing, line length, metrics | `bin/lint` |
| **This file** | Idiom and naming — what to call things, how to shape them, how to comment | Review |

If this file and RuboCop disagree, RuboCop wins; fix this file. If this file and
SKILL.md appear to disagree, you have found a bug in one of them — say so rather
than picking.

**The rule above all of these is still the first rule in SKILL.md: read the
neighbours and match them.** A guide cannot anticipate every case. The two or
three files closest to what you are changing can.

---

## 1. Comments

The house style is unusual and it is deliberate: **comments explain why, and
they often warn.** A comment that restates the code is deleted on sight.

Three kinds earn their place.

**The header comment** — what this file is for, on anything non-obvious:

```ruby
# Base for service objects.
#
# Services exist for multi-step operations that touch more than one model or
# have to coordinate with the outside world — inviting a member, processing a
# Stripe event, deleting an account.
```

**The warning** — the reason the obvious alternative is wrong. These are the most
valuable comments here, because they survive the next person's good intentions:

```ruby
# Reads local state only. Never call Stripe to answer this — the webhook is
# what keeps it true, and a request must not depend on Stripe being up.
def subscription_active? = subscription&.active? || false
```

```ruby
# Built with team_id rather than team: assigning the association would push
# this unsaved placeholder into the team's has_one cache via inverse_of, and
# a later read of team.subscription would return the blank record.
```

**The pointer** — one line naming the thing that matters, so a reader knows where
to look first:

```ruby
# The one line that matters.
def scoped_projects = current_team.projects
```

Rules:

- Write sentences. Capital letter, full stop
- Use an em dash for the aside, as above. It is the house punctuation
- Never leave a commented-out block. Git remembers it
- Never write `# TODO` without a name and a reason. Prefer an issue
- A `rubocop:disable`, a Brakeman ignore, or a bundler-audit ignore **must** carry
  a comment giving the specific reason it is safe (SKILL.md §10)

Files that teach carry an `EXAMPLE` header in capitals — `ProjectsController`,
`ProjectPolicy`. Do not add new ones; the two that exist are the tour.

---

## 2. Ruby

### Endless methods for one-liners

If the body is a single expression, use the endless form. This is the single
most visible idiom in the codebase:

```ruby
def owners = users.merge(Membership.owner)
def seat_count = memberships.count
def to_param = slug
def member? = membership.present?
```

Multi-line bodies use `def ... end` normally. Do not force an expression to fit.

### Align a run of related predicates

When several one-line predicates form a block, align the `=`. It turns a list
into a table:

```ruby
def index?   = membership.present?
def show?    = membership.present?
def create?  = admin_or_above?
def new?     = create?
def update?  = admin_or_above?
def edit?    = update?
def destroy? = admin_or_above?
```

Do not align across unrelated groups, and do not align assignments in ordinary
method bodies.

### Naming

| Kind | Convention | Example |
|---|---|---|
| Predicate | Ends in `?`, reads as a question | `subscription_active?`, `admin_or_above?` |
| Bang | Only when it raises or mutates the receiver | `destroy!`, `save!` |
| Service | `Namespace::VerbNoun` — an imperative | `Teams::InviteMember`, `Billing::SyncSeats` |
| Job | The service name plus `Job` | `Billing::SyncSeatsJob` |
| Policy | `ModelPolicy` | `ProjectPolicy` |
| Scoped reader | `scoped_<plural>` | `scoped_projects` |
| Boolean local | Positive, never negated | `selected`, not `not_selected` |

Namespace services and jobs by domain: `Teams::`, `Billing::`, `Users::`,
`Admin::`. A service that does not fit one of those is a hint that the domain
list needs a new entry — not that it should go at the top level.

### Guard clauses over nesting

Return early. The happy path stays at one level of indentation:

```ruby
def short_date(time)
  return "—" if time.blank?

  tag.time(time.to_date.to_fs(:long), datetime: time.iso8601, title: time.iso8601)
end
```

A blank line after the guard block, always.

### Strings

Double quotes everywhere (omakase). Every file opens with
`# frozen_string_literal: true` followed by a blank line — RuboCop enforces it,
so autocorrect will add it for you.

---

## 3. Models

Order inside a model, top to bottom:

1. Schema annotation (generated — see below)
2. `include`s
3. Constants
4. Associations
5. Validations
6. Callbacks
7. Scopes
8. Enums / delegations
9. Public methods
10. `private`

The schema block at the top of each model is generated by `annotaterb`. **Never
hand-edit it.** It refreshes when migrations run.

Scopes that take an argument use the lambda form and handle the empty case
first, so a caller never has to:

```ruby
scope :search, ->(term) {
  next all if term.blank?

  pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
  where("name ILIKE :q OR slug ILIKE :q", q: pattern)
}
```

Note `sanitize_sql_like` and the named bind. Interpolating a user string into a
`where` is a security bug, not a style preference.

Invariants that must always hold live on the model, never in the service that
happens to call it (SKILL.md §3).

---

## 4. Controllers

[ProjectsController](app/controllers/projects_controller.rb) is the reference.
Read it before writing a new one.

Shape:

```ruby
class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show edit update destroy]

  # ... RESTful actions in canonical order:
  # index, show, new, create, edit, update, destroy

  private

  def scoped_projects = current_team.projects

  def set_project
    @project = scoped_projects.find(params[:id])
  end

  def project_params
    params.expect(project: %i[name description])
  end
end
```

- **Actions in REST order.** Do not group by verb or by permission
- **One `scoped_<plural>` private reader** that every action starts from. It is
  the auditable line; give it its own method rather than repeating
  `current_team.projects` seven times
- `before_action :set_<model>` with an explicit `only:` list, using `%i[]`
- Strong params use **`params.expect`**, not `params.require(...).permit(...)`.
  This is Rails 8 and `expect` handles a malformed body correctly
- Never permit `team_id`. The record gets its team from the scoped relation

### Responses

```ruby
redirect_to @project, notice: "Project created."
render :new, status: :unprocessable_content
redirect_to projects_path, notice: "Project deleted.", status: :see_other
```

- Flash messages are **complete sentences with a full stop**, sentence case:
  `"Project created."`, not `"project created"` or `"Project created!"`
- A failed create or update re-renders with **`:unprocessable_content`** (the
  Rails 8 name — not `:unprocessable_entity`)
- A `destroy` that redirects uses **`status: :see_other`**, so Turbo follows it
- `authorize` is called inside each action, after the record is loaded

Keep bodies short. A controller action past a dozen lines is usually a service
waiting to be extracted — but read SKILL.md §3 before extracting one, because
most of them should not be.

---

## 5. Policies

Predicates only, aligned, endless. Delegate rather than repeat:
`def new? = create?`.

Compare roles, never enumerate them:

```ruby
def update? = admin_or_above?     # not: membership.admin? || membership.owner?
```

Group predicates with a comment when the reasoning is not obvious from the
names:

```ruby
# Any member may create and edit project content; destroying is a permanent
# loss, so it takes an admin.
def create? = member?
def update? = member?
def destroy? = admin_or_above?
```

A policy never checks `record.team == Current.team`. If you feel the need, the
controller scoped its query wrongly — fix the controller (SKILL.md §1).

---

## 6. Services

```ruby
module Teams
  class InviteMember < ApplicationService
    def initialize(team:, email:, role:, invited_by:)
      @team = team
      @email = email.to_s.strip.downcase
      @role = role
      @invited_by = invited_by
    end

    def call
      return failure_from(invitation) unless invitation.save

      success(invitation)
    end

    private

    def deliver(invitation)
      TeamMailer.invitation(invitation).deliver_later
      success(invitation)
    end
  end
end
```

- `module` + `class`, nested. Not `class Teams::InviteMember`
- **Keyword arguments only.** Never positional
- Normalise input in `initialize` (`email.to_s.strip.downcase`), so `call` works
  on clean values
- Read `@ivar`s directly in the body. Do not add `attr_reader` for them
- `call` is the only public method. Everything else is private
- Every exit returns `success(...)` or a `failure...`. Never a bare `true`,
  `nil`, or a raise for an expected failure
- Extract a private method when a branch needs a name (`deliver`,
  `expired_invitation`)

---

## 7. Views and ERB

### Structure

```erb
<% content_for :title, "Projects" %>

<%= page_title "Projects", description: "Scoped to #{current_team.name}." do %>
  <%= link_to "New project", new_project_path, class: "btn btn--primary" %>
<% end %>
```

- Every page sets `content_for :title`, first line
- Every page header goes through the `page_title` helper, not hand-written markup
- Partials get **explicit locals**, never a shared instance variable:
  `render "shared/pagination", page: @page`
- Reusable partials live in `app/views/shared/` with a leading underscore

### Logic in templates

Keep it to presentation. A conditional that picks a class or a string is fine; a
conditional that decides policy is not.

Ask the policy, never the role (SKILL.md §2):

```erb
<% if policy(project).update? %>
  <%= link_to "Edit", edit_project_path(project), class: "btn-link" %>
<% end %>
```

When a helper would be asked the same question by three templates, write the
helper. [ApplicationHelper](app/helpers/application_helper.rb) shows the pattern
— helpers build markup with `tag.`, return `"—"` for blank input, and centralise
a mapping so each view does not repeat it:

```ruby
def role_badge(membership)
  variant = membership.owner? ? "accent" : "quiet"
  tag.span(membership.role_label, class: "badge badge--#{variant}")
end
```

### Accessibility and empty states

These are not optional polish; the example views all do them:

- An icon-only or implied column header gets `<span class="visually-hidden">`
- `<nav>` landmarks carry `aria-label`
- A disabled-looking control is `aria-disabled="true"`, not a removed link
- Missing values render as an em dash: `project.created_by&.name || "—"`
- Every list has an `.empty` block, and it distinguishes *no records* from
  *nothing matched your search*
- Anything driven by Stimulus has a `<noscript>` fallback where the action still
  matters — see the search field in
  [projects/index](app/views/projects/index.html.erb)

---

## 8. Stimulus

Registration is explicit in
[controllers/index.js](app/javascript/controllers/index.js). Add the import and
the `application.register` line by hand; there is no auto-loading.

```js
import { Controller } from "@hotwired/stimulus"

// Client-side tabs. Use these only when all panels are cheap to render at once;
// otherwise use real links and let Turbo Drive load each view.
//
//   <div data-controller="tabs" data-tabs-active-value="details">
//     <button data-tabs-target="tab" data-tab="details" data-action="tabs#select">Details</button>
//     <section data-tabs-target="panel" data-tab="details">…</section>
//   </div>
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String }
}
```

- **Anonymous default export.** `export default class extends Controller`, never
  a named class
- **A header comment with a markup example.** Every controller has one. It is how
  the next person uses your controller without reading its body
- `static targets` / `static values` first, then `connect()`, then actions, then
  render helpers
- Prefer a `*ValueChanged()` callback over calling `render()` from each action —
  state changes in one place, the DOM follows
- No semicolons. Double quotes. This matches the existing files; there is no JS
  linter, so matching them by hand is the whole mechanism
- Read state from `dataset`, write state to targets. Do not query the document
- Actions that handle a click call `event.preventDefault()` first

Before writing a controller, check the seven that exist (SKILL.md §4).

---

## 9. SASS

Naming is BEM, with a state prefix:

```scss
.table { }             // block
.table__primary { }    // element  — two underscores
.btn--ghost { }        // modifier — two hyphens
.is-numeric { }        // state    — is- prefix, may be nested
```

File conventions:

```scss
@use "../abstracts/mixins" as *;
@use "../abstracts/breakpoints" as *;
```

- `@use` at the top, `as *` so mixins read unqualified. Never `@import`
- **Every value is a token.** `var(--space-4)`, `var(--text-sm)`,
  `var(--border)`. A raw hex, px, or font-weight in a component file is a bug —
  the tokens are in
  [abstracts/_variables.scss](app/assets/stylesheets/abstracts/_variables.scss)
- Breakpoints are mixins: `@include sm { ... }`. Never a bare media query
- Mixins are named for what they produce: `label`, `scroll-x`, `display-type`
- One-line rules stay on one line: `.pagination__count { color: var(--ink-tertiary); }`
- `//` comments, not `/* */`
- Nest one level for elements and states. Do not nest to build a name — write
  `.table__primary`, not `.table { &__primary { } }`, so the class is greppable
- Add the partial to `application.scss` by hand, in the right section

Never write a dark-mode branch in a component. Dark mode redefines tokens and
nothing else (SKILL.md §5).

Run the app and open **`/styleguide`** to see every token and component rendered
from the real stylesheet. When you add or change a component, add it there in the
same change — the page is markup and a chrome-only partial
(`pages/_styleguide.scss`), and it carries no copy of a token or a component rule.

---

## 10. Specs

Describe behaviour, not methods:

```ruby
RSpec.describe "Projects" do
  describe "creating" do
    let(:tenant) { create_tenant }

    before { sign_in tenant.member }

    it "assigns the project to the active team, never to a team from params" do
      other = create_tenant

      post projects_path, params: {
        project: { name: "Smuggled", team_id: other.team.id }
      }

      expect(Project.find_by(name: "Smuggled").team).to eq(tenant.team)
    end
  end
end
```

- `describe` a behaviour in words (`"creating"`, `"authorization"`, `"search"`),
  not `"#create"`
- **`it` reads as a sentence that states the guarantee.** Long is fine — RuboCop's
  wording and length cops are off on purpose. Say what must be true, and say the
  dangerous case out loud: *"…never to a team from params"*
- Blank line between setup, action, and expectation. Three visual beats
- `create_tenant` from
  [tenancy_helpers](spec/support/tenancy_helpers.rb) is how you get a team with
  roles. Do not hand-build memberships
- `let!` where the record must exist before the example runs — this is explicitly
  allowed here
- Assert the negative too. A permission spec that only proves the happy path
  proves nothing
- A comment above a subtle expectation explains the attack it is closing:

```ruby
# Even if a team_id is smuggled in, the record belongs to the active team:
# the controller builds it from current_team.projects and team_id is not
# a permitted parameter.
```

What each directory is for, and what new work must include, is SKILL.md §9.

---

## 11. Migrations

- One migration, one change. A rename and a backfill are two
- Every foreign key gets an index and a real `foreign_key: true`
- `null: false` on anything the model validates as present
- Backfills go in a job or a rake task, not in the migration, once the table is
  big enough to matter
- Never edit a migration that has run anywhere but your laptop
- `db/schema.rb` is generated. Commit it; do not hand-edit it

Metrics cops are off for `db/migrate` — a migration reads as one long
declaration and that is fine.

---

## 12. Before you push

```bash
bin/lint --fix    # autocorrect, then read what it changed
bin/ci            # everything CI runs
```

`bin/ci` is the contract: if it passes, the pull request should be green. Do not
claim something works without running it.

---

## Quick reference

| Do not | Instead |
|---|---|
| `params.require(:x).permit(...)` | `params.expect(x: %i[...])` |
| `status: :unprocessable_entity` | `status: :unprocessable_content` |
| A `destroy` redirect without a status | `status: :see_other` |
| `class Teams::InviteMember` | `module Teams` + nested `class` |
| Positional args to a service | Keyword arguments |
| `attr_reader` for a service's own ivars | Read `@ivar` directly |
| A raw colour, size, or spacing in SCSS | A `var(--token)` |
| `@import` in SCSS | `@use ... as *` |
| A bare media query | `@include sm { }` |
| `.table { &__primary { } }` | `.table__primary { }` |
| A named Stimulus class export | `export default class extends Controller` |
| A Stimulus controller with no usage comment | A header comment with example markup |
| `describe "#create"` | `describe "creating"` |
| A comment restating the code | A comment saying why, or nothing |
| Hand-editing the schema annotation | `annotaterb`, via migrations |
