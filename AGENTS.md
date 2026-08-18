# Teeeemplate

Read **[SKILL.md](SKILL.md)** before writing or modifying code. It is the
architectural contract for this repository and it is short.

The three things that catch people out:

1. **Every query starts from the team.** `current_team.projects.find(id)`, never
   `Project.find(id)`. Another team's record must 404, not 403.
2. **Tenant scoping and Pundit are both required.** Scoping decides which records
   exist for you; Pundit decides what you may do with them. Neither substitutes
   for the other.
3. **A Stripe redirect is not proof of payment.** The webhook is the source of
   truth, it is signature-verified, and it is idempotent.

Setup and commands are in [README.md](README.md). Run `bin/ci` before you claim
something works.
