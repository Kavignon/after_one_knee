# AfterOneKnee

Bilingual (EN/FR) wedding RSVP app for our own wedding. Phoenix 1.8, LiveView, SQLite. It replaces an earlier agent-built prototype. The repo is public and meant to show Québec Law 25 practices, so privacy and security bugs block release.

## Settled product decisions

- **Guests** get one RSVP link per household and no account. The token is stored hashed, with a version so it can be revoked. On first visit, `/r/:token` swaps the token for a signed session and redirects to `/rsvp`, so the token leaves the URL.
- **Admins** are the two of us, through `phx.gen.auth` magic links. Public registration is removed. Admin accounts are created by a release task.
- **Meal choice, dietary details, allergy severity and age category are per guest**, never per household. Seating (tables and seat assignments) comes later and must drop in without migrating existing data.
- **Guests can edit their answers until the RSVP deadline.**
- **Event content** (venue, dates, times, descriptions) lives in the database, never in code or templates.

## Launch scope

- Admin auth, a read-only dashboard, CSV export.
- Data model with enums, constraints and encryption.
- Household scope; RSVP per invited event; meals, dietary, songs; EN/FR; edits until the deadline; a confirmation email.
- Release tasks: import the guest CSV, generate RSVP links, send an invite wave (dry run by default, never sends twice to the same household for the same wave).
- Bilingual privacy notice, including how long data is kept.
- Litestream backups, error tracking, log redaction, rate limits, CSP and HSTS.

Out of scope until after the first wave: admin editing screens, reminders, change history, seating, push notifications, TOTP, a demo mode, and export or erasure screens (handled by hand meanwhile).

## Go/no-go before any real invite

1. Only the two admins can sign in. No public registration. The dashboard requires login.
2. An RSVP link reads and writes only its own household, proven by a test with a forged guest id.
3. Answers save exactly as entered: attending or declining, meal per person, dietary details. Editable until the deadline.
4. No tokens or personal data in logs, proven by a test.
5. Backups run, and one restore has been tested.
6. An invite from our domain lands in Gmail, Outlook and iCloud inboxes, and its link survives a link scanner opening it.
7. The RSVP page shows the bilingual privacy notice.
8. Error tracking alerts Kevin.

## Architecture rules

- Every context function that reads or writes guest data takes a `%Scope{}` as its first argument and filters by it. A guest scope is one household. An admin scope is a signed-in admin.
- Statuses and other closed sets use `Ecto.Enum`, backed by CHECK constraints in migrations.
- Business rules (who may answer which event, a meal only when attending, the deadline) live in a pure module with unit tests. LiveViews stay thin.
- Personal data columns use the Cloak-encrypted type. Lookups use HMAC blind indexes over normalized values (trimmed, lowercased emails).
- The confirmation email is sent only after the RSVP transaction commits.
- The wave task sends one household at a time, respects the email provider's rate limit, and records each send so a rerun skips households already sent.

## Elixir rules

- Preload associations explicitly before using them.
- Get LiveView callback return shapes right. `handle_event/3` returns `{:noreply, socket}`.
- Prefer pattern matching and `with` over nested `case`. Prefer comprehensions over `Enum.reduce` for building lists.
- Never call `String.to_atom/1` on input.
- Use generators where they exist instead of hand-writing what they produce.

## Hard rules

- Never run `fly`, seeds or migrations against production. The project settings block the `fly` CLI.
- Never build the Docker image locally with `--platform linux/amd64` on Apple Silicon. OTP's JIT breaks under emulation and fails with misleading "already compiled" errors.
- Never commit secrets, `.env`, `*.db`, `*.db-wal` or `*.db-shm`.
- Never trust ids from the client (`phx-value-*`, params). Derive access from the scope.
- Never log tokens, emails, names or dietary details.
- `rel/overlays/bin/server` must start with `#!/bin/sh` as its very first bytes and stay executable. The container runs as root because the Fly volume is root-owned.
- One concern per PR. Every bug fix starts with a failing test.
- Never call work done without `mix precommit` output from the current code.

## Commands

```sh
set -a; source .env; set +a   # local throwaway CLOAK_KEY and HMAC_KEY
mix setup
mix precommit
```

`mix precommit` is the single gate for agents and CI. If it isn't defined yet, add this alias to `mix.exs`:

```elixir
precommit: [
  "compile --warnings-as-errors",
  "deps.unlock --check-unused",
  "format --check-formatted",
  "credo --strict",
  "sobelow",
  "test"
]
```

## Production

- Fly app `after-one-knee`, region `yyz`, one machine, volume mounted at `/data`.
- At cutover, `DATABASE_PATH` points to `/data/after_one_knee_v2.db`, a fresh file.
- Migrations run at boot through `Ecto.Migrator` in the supervision tree.
- Kevin deploys by hand with `fly deploy --remote-only`.

## The prototype

The old app lives next to this repo at `../after_one_knee_prototype`. Start a session with `claude --add-dir ../after_one_knee_prototype` when you need it. Use it for UI, copy and translations only. Never copy its code without review: it has known security bugs.
