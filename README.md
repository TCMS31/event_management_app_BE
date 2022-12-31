# Event Management API

A Rails 7.1 **API-only** service for organising and joining events. Users
register, receive a JWT, create events they organise, browse upcoming events
they have not joined, and join them. It is the server half of a two-repository
pair; the React client lives in
[`event_management_FE`](https://github.com/TCMS31/event_management_FE).

There is no user interface here — no views, no assets, no HTML. Every response
is JSON.

## Captured output

This is an API, so the evidence is request/response pairs rather than
screenshots. Everything under `docs/captured/` is the literal output of a
command that was actually run; none of it is hand-written.

| File | What it is |
|---|---|
| [`docs/captured/api-session.txt`](docs/captured/api-session.txt) | 21 real curl exchanges against a booted server: health check, signup, login, the full event lifecycle, the authorization refusals, token revocation, CORS headers |
| [`docs/captured/query-benchmark.txt`](docs/captured/query-benchmark.txt) | Before/after timings and an `EXPLAIN ANALYZE` for the query rewrite described under [Scalability](#scalability) |
| [`docs/captured/mutation-check.txt`](docs/captured/mutation-check.txt) | The test suite being deliberately broken and repaired, to show it can fail |
| [`docs/captured/baseline-bug-probe.txt`](docs/captured/baseline-bug-probe.txt) | The defects reproduced on the pristine checkout, before any of them were fixed |
| [`docs/captured/json-3-regression.txt`](docs/captured/json-3-regression.txt) | Why the Gemfile pins `json ~> 2.7`, demonstrated rather than asserted |

A taste of the first file — the authorization hole that this pass closed:

```
$ curl -s -i -X PUT http://127.0.0.1:8690/api/v1/events/7 -H "Authorization: $GRACE" \
       -H 'Content-Type: application/json' -d '{"event":{"name":"Hijacked"}}'
HTTP/1.1 403 Forbidden
{"errors":["You are not allowed to perform this action"]}

$ curl -s -H "Authorization: $ADA" http://127.0.0.1:8690/api/v1/events/7
name is still: Zero Downtime Migrations | organizer_id: 1
```

…and the login handshake the React client depends on:

```
$ curl -s -D - -o /dev/null -X POST http://127.0.0.1:8690/login \
       -H 'Content-Type: application/json' \
       -d '{"user":{"email":"ada@example.com","password":"password123"}}'
HTTP/1.1 200 OK
authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI2MGNlNmY3YS03Nzc0LTRiMjYtO
```

## Architecture

```mermaid
flowchart TB
    Client["React client<br/>event_management_FE"]

    subgraph Rack["Rack middleware"]
        CORS["Rack::Cors<br/>exposes Authorization"]
        Warden["Warden + devise-jwt<br/>decodes the bearer token"]
    end

    subgraph Controllers["Controllers"]
        Sessions["Users::SessionsController<br/>Users::RegistrationsController"]
        ApiBase["Api::ApiController<br/>ExceptionHandler + Authorization + Paginatable"]
        Events["Api::V1::EventsController"]
    end

    Policies["app/policies<br/>EventPolicy — may this user do this?"]
    Models["app/models<br/>Event · User · EventUser<br/>validations and query scopes"]
    Serializers["app/serializers<br/>jsonapi-serializer, attributes only"]
    DB[("PostgreSQL")]

    Client -->|"JSON + Authorization header"| CORS
    CORS --> Warden
    Warden --> Sessions
    Warden --> ApiBase
    ApiBase --> Events
    Events -->|"authorize!(record, :update)"| Policies
    Events --> Models
    Policies --> Models
    Models --> DB
    Events --> Serializers
    Serializers -->|"flat JSON"| Client
```

Dependencies point inward: controllers know about policies, models and
serializers; none of those knows about a controller. The only shared mutable
state is the database.

## Request flow

The flow below is the one the client exercises most: sign in, list what you
organise, then try to edit something you do not own.

```mermaid
sequenceDiagram
    autonumber
    participant C as React client
    participant W as Warden / devise-jwt
    participant E as EventsController
    participant P as EventPolicy
    participant DB as PostgreSQL

    C->>W: POST /login {user: {email, password}}
    W->>DB: find user, verify bcrypt digest
    DB-->>W: user
    W-->>C: 200 + Authorization: Bearer <jwt>

    C->>W: GET /api/v1/events (Bearer <jwt>)
    W->>DB: verify signature, match jti
    W->>E: current_user
    E->>DB: SELECT ... WHERE organizer_id = ? LIMIT 50
    DB-->>E: rows
    E-->>C: 200 [Event, ...] + X-Total-Count

    C->>W: PUT /api/v1/events/9 (Bearer <jwt>)
    W->>E: current_user
    E->>DB: Event.find(9)
    E->>P: update?
    alt caller is the organizer
        P-->>E: true
        E->>DB: UPDATE events ...
        E-->>C: 200 Event
    else caller is anybody else
        P-->>E: false
        Note over E: raises NotAuthorizedError
        E-->>C: 403 {"errors": ["You are not allowed..."]}
    end

    C->>W: DELETE /logout (Bearer <jwt>)
    W->>DB: rotate jti
    W-->>C: 200 — the old token is now dead
```

## Quickstart

Requires Ruby 3.2.2 and a PostgreSQL server.

```bash
bundle install
cp .env.example .env          # fill in DATABASE_* if your PostgreSQL needs credentials
bin/rails db:create db:schema:load db:seed
bin/rails server              # http://localhost:3000
```

The seed creates three users — `ada@example.com`, `grace@example.com`,
`alan@example.com`, all with the password `password123` — and six events, so
every list endpoint returns something immediately.

```bash
TOKEN=$(curl -s -D - -o /dev/null -X POST http://localhost:3000/login \
  -H 'Content-Type: application/json' \
  -d '{"user":{"email":"ada@example.com","password":"password123"}}' \
  | tr -d '\r' | awk 'tolower($1)=="authorization:"{print $2" "$3}')

curl -s -H "Authorization: $TOKEN" http://localhost:3000/api/v1/events
```

### With Docker

```bash
cp .env.example .env          # DEVISE_JWT_SECRET_KEY and SECRET_KEY_BASE are required
docker compose up --build     # API on :8690, PostgreSQL on :8695
```

> The container image and compose file in this repository have **not been built
> or booted**. They were authored and validated with `docker compose config`
> only; the Docker daemon was unavailable when this work was done.

## Configuration

Nothing is read from source. `config/database.yml` and
`config/initializers/devise.rb` both read the environment.

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `DEVISE_JWT_SECRET_KEY` | **yes** outside development/test | `secret_key_base` in dev/test | Signs and verifies every JWT. Anyone holding it can mint a token for any user. The app refuses to boot without it in production. Generate with `bin/rails secret` |
| `SECRET_KEY_BASE` | **yes** in production | — | Rails' own key derivation |
| `DATABASE_URL` | no | — | Full connection URL; overrides the variables below |
| `DATABASE_HOST` | no | `localhost` | |
| `DATABASE_PORT` | no | `5432` | |
| `DATABASE_NAME` | no | `event_management_app_be_<env>` | |
| `DATABASE_USERNAME` | no | the OS user | |
| `DATABASE_PASSWORD` | no | — | |
| `TEST_DATABASE_NAME` | no | `event_management_app_be_test` | Lets a CI job isolate its database |
| `JWT_EXPIRATION_MINUTES` | no | `480` | Token lifetime |
| `CORS_ORIGINS` | no | `*` | Comma-separated allowed origins. Pin it in production |
| `RAILS_MAX_THREADS` | no | `5` | Puma threads **and** the Active Record pool size |
| `PORT` | no | `3000` | |
| `PUMA_SOCKET_DIR` | no | — | If set, Puma binds a Unix socket there instead of a TCP port |
| `SEED_PASSWORD` | no | `password123` | Password given to the seeded demo users |

## Development

```bash
bundle exec rspec                     # the full suite
bundle exec rspec spec/requests       # just the HTTP-level specs
bundle exec rubocop                   # lint
bundle exec rubocop -a                # lint with safe autocorrect
bin/rails db:seed                     # idempotent; safe to re-run
```

The suite needs a PostgreSQL server (the schema uses the `plpgsql` extension and
the scopes use a correlated subquery, so SQLite is not a substitute). Point it
at a non-default instance with `DATABASE_HOST` / `DATABASE_PORT`.

`.github/workflows/ci.yml` runs the linter and the suite against
`postgres:16-alpine` on every push and pull request.

## Project structure

```
app/
  controllers/
    api/
      api_controller.rb           Base for every /api endpoint: authentication,
                                  error handling, authorization, pagination
      v1/events_controller.rb     The eight event endpoints. Two or three lines
                                  of body per action; the rest is delegated
    concerns/
      authorization.rb            authorize!(record, :action) -> 403 or proceed
      exception_handler.rb        Exceptions -> the two JSON error envelopes
      paginatable.rb              LIMIT/OFFSET + X-Total-Count headers
      rack_sessions_fix.rb        A disabled session, because Devise expects one
    users/                        Devise's signup/login/logout, rendered as JSON
  models/                         Event, User, EventUser: validations and scopes
  policies/                       Who may do what. Denies by default
  serializers/                    Record -> the flat JSON the client parses
config/
  initializers/
    cors.rb                       Exposes Authorization and the page headers
    devise.rb                     Reads the JWT secret from the environment
  routes.rb
db/
  migrate/                        Schema history, including the unique index on
                                  event_users(user_id, event_id)
  seeds.rb                        Idempotent demo data, no test-gem dependency
docs/
  api-contract.md                 The contract the React client relies on
  captured/                       Real transcripts; see "Captured output" above
spec/
  policies/                       The authorization rules in isolation
  requests/
    api/v1/events_spec.rb                 Behaviour of each endpoint
    api/v1/events_authorization_spec.rb   The cross-user matrix
    authentication_spec.rb                Signup/login/logout over real JWTs
  models/ serializers/ factories/ support/
```

## Design notes

### The layering, and why there is a policy object at all

The original controller carried the business rules inline: which events to list,
who may touch them, how to shape errors. Four of the seven actions had their own
`begin/rescue`. The rewrite moved each concern to the layer that owns it —
*what to fetch* to model scopes, *who may* to `app/policies`, *how to report
failure* to `ExceptionHandler` — which is why the actions are now three lines
each and why `create` can simply call `save!`.

`EventPolicy` earns its place because of what was there before. Every mutating
endpoint was reachable by any authenticated user against any event: a cross-user
`PUT` returned 200, rewrote the record **and** reassigned `organizer_id` to the
caller, because the strong parameters defaulted `organizer_id` to
`current_user.id` on update as well as on create. A cross-user `DELETE` returned
204 and destroyed the row. Both are reproduced in
[`docs/captured/baseline-bug-probe.txt`](docs/captured/baseline-bug-probe.txt).

The fix is a class whose predicates all deny by default, plus
`authorize!(record, :action)` which *raises* rather than returning false. A new
endpoint that forgets to authorize fails closed, and the rule is unit-tested
without booting a controller.

### Scalability — the real bottleneck was one scope

The interesting query is "upcoming events I have neither organised nor joined".
It used to read:

```ruby
where.not(id: user.events.ids | Event.organized_by_user(user).ids)
```

Three round trips: two to collect ids, one to send them all back inside a
`NOT IN (…)` list that grows with the user's history. It is now a single
statement with a correlated `NOT EXISTS`, which the new unique index on
`event_users(user_id, event_id)` serves as an index-only scan.

Measured on 20,000 events of which the user had joined 5,000
([`docs/captured/query-benchmark.txt`](docs/captured/query-benchmark.txt)):

| | ms per call | queries |
|---|---|---|
| Before | 15.7 | 3 |
| After | 0.2 | 1 |

That is roughly 80×, and `EXPLAIN ANALYZE` confirms a `Merge Anti Join` over
`index_event_users_on_user_id_and_event_id` rather than a sequential scan.

Two other honest limits were addressed:

- **Unbounded lists.** Every collection action returned the entire result set.
  `Paginatable` caps that at 100 rows (default 50) and reports the window in
  headers, so the body stays a bare array.
- **Missing indexes.** `event_users(user_id, event_id)` is now unique — the
  "join an event only once" rule was previously enforced only by a validation,
  which left a race between the `SELECT` and the `INSERT` — and `events(date)`
  is indexed for the upcoming-events filter and sort.

What was *not* done, deliberately: no caching layer, no background queue, no
read replica. This workload is a handful of indexed queries per request. Adding
infrastructure would be decoration.

### Extensibility — one seam

`app/policies` is the seam a future developer will actually reach for. Every
realistic next requirement on this domain is an authorization question:
co-organizers, admin moderation, private events, capacity limits closing the
join action. All of them are a predicate on `EventPolicy` or a sibling class —
no controller changes, and each one testable in isolation.

`Paginatable` and `ExceptionHandler` are the two smaller seams: any future
controller gets bounded lists and the house error format by inheriting from
`Api::ApiController`.

### Why the odd endpoint names survive

`add_user_to_events`, `get_events` and `joined_events` are not names anyone would
choose. They are also the exact paths the deployed React client calls. Renaming
them would be a breaking change to the only consumer in exchange for tidiness,
so they stayed, with a comment and a RuboCop exemption explaining why.

### Bugs fixed

Reproduced on the pristine checkout before being fixed; each has a regression
test named after it.

| | |
|---|---|
| Any user could update, take over or delete any event | `spec/requests/api/v1/events_authorization_spec.rb` |
| The JWT signing key was hardcoded in two files | now `DEVISE_JWT_SECRET_KEY` |
| The production database password was committed | now `DATABASE_PASSWORD` |
| `has_many :events` was declared twice on `User`; the second silently replaced the first, dropping `dependent: :destroy`, so deleting a user who had organised anything raised `PG::ForeignKeyViolation` | `spec/models/user_spec.rb` |
| A missing event returned **200** with the raw exception message as the body | `spec/requests/api/v1/events_spec.rb` |
| A missing `event_id` parameter returned **200** with the raw exception message | same |
| Empty lists returned **204** with a JSON body, which Rack discards | same |
| `upcoming_events` used `Time.now`, so the cut-off followed the process time zone rather than the application's | `spec/models/event_spec.rb` |
| An organizer could join their own event, creating a row unreachable from any list | `spec/requests/api/v1/events_authorization_spec.rb` |
| `config/puma.rb` hardcoded `/var/www/Event-Management` for every non-development environment, so a production boot — the container included — died on a missing directory | — |
| `db/seeds.rb` required `factory_bot`, tying `db:seed` to a test-only gem | — |
| 16 FontAwesome font files and a `public/fonts/README.md` describing a "Blockchain Explorer" had been committed into this API-only app, referenced by nothing | deleted |

### A trap worth naming

Adding RuboCop resolves `json` to 3.x, and on Rails 7.1 that breaks
`ActionDispatch`'s request-body parsing: every request carrying a JSON body —
signup, login, create, update — returns 500 with
`ActionDispatch::Http::Parameters::ParseError`, while the application still
boots and `GET /up` still answers 200. The failure is therefore invisible to a
health check.

This was measured rather than assumed: the unpinned bundle was built, booted and
curled, and the transcript is in
[`docs/captured/json-3-regression.txt`](docs/captured/json-3-regression.txt).
The Gemfile pins `json ~> 2.7` with that reasoning inline. Worth noting that the
new suite *does* catch it — 42 of 122 examples fail — because the request specs
now post real JSON bodies; the original specs did not, and would have stayed
green.

## Limitations

- **The container image is unbuilt.** `Dockerfile`, `docker-compose.yml` and
  `.dockerignore` were authored to a multi-stage, non-root, healthchecked
  standard and validated with `docker compose config`, but never built or booted.
- **No refresh tokens.** A JWT lives for eight hours and then the user logs in
  again. There is no rotation and no sliding expiry.
- **Pagination is offset-based.** Fine at this scale; a deep page on a very
  large table will still make PostgreSQL count past the offset. Keyset
  pagination would be the next step, and it would change the contract.
- **`config/credentials.yml.enc` is committed without its `master.key`**, so it
  cannot be decrypted by anyone cloning this repository. Nothing reads from it —
  every secret comes from the environment — but it remains as dead weight rather
  than being deleted, because removing an encrypted credentials file is the kind
  of change the repository owner should make knowingly.
- **`devise-jwt` 0.11 calls `Rails.application.secrets`**, which Rails 7.1
  deprecates and Rails 7.2 removes. Upgrading Rails will require upgrading that
  gem first. The deprecation warning on boot comes from there, not from this
  application's code.
- **No rate limiting** on `/login` or `/signup`.
- **Participants are never rendered.** `EventSerializer` declares
  `has_many :users`, but the controllers render only the attributes hash, so no
  response includes attendees. This matches what the client needs; the
  declaration is left in place as the obvious hook for an endpoint that does.
- **No soft deletes.** Deleting an event destroys its attendance rows with it.
