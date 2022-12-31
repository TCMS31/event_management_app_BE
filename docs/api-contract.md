# API contract

This is the contract the React client in `event_management_FE` depends on. Every
status code and body shape below is reproduced verbatim in
[`captured/api-session.txt`](captured/api-session.txt), which is the literal
output of curl against a locally booted server — not a hand-written example.

## Authentication

A JWT is issued by `POST /login` in the **`Authorization` response header**, not
in the body. The client stores it and sends it back unchanged (the header value
already includes the `Bearer ` prefix).

`Access-Control-Expose-Headers` lists `Authorization`, without which a browser
cannot read that header at all. Removing it breaks login from the browser while
leaving every curl test green.

Tokens expire after `JWT_EXPIRATION_MINUTES` (default 480) and are revoked on
logout by rotating the user's `jti` column.

## Error envelopes

Two shapes, and only two:

| Shape | When |
|---|---|
| `{"errors": ["message"]}` | 400, 403, 404, 500 — a message fit to show a user |
| `{"attributes_errors": {"field": ["message"]}}` | 422 — per-field validation failures |

The Devise endpoints predate this convention and keep their own shape, because
the client parses them:

| Endpoint | Success | Failure |
|---|---|---|
| `POST /signup` | `{"status":{"code":200,"message":"..."},"data":{…user}}` | `{"status":["Email has already been taken"]}` — an **array** |
| `POST /login` | `{"status":{"code":200,"message":"...","data":{"user":{…}}}}` | Devise's 401 |
| `DELETE /logout` | `{"status":200,"message":"Logged out successfully."}` | `{"status":401,"message":"Couldn't find an active session."}` |

## Endpoints

| Method | Path | Auth | Success | Notes |
|---|---|---|---|---|
| `GET` | `/up` | no | 200 | Health probe; touches the database |
| `POST` | `/signup` | no | 200 | Body `{"user":{"name","email","password"}}` |
| `POST` | `/login` | no | 200 | Body `{"user":{"email","password"}}`; token in the `Authorization` header |
| `DELETE` | `/logout` | bearer | 200 | Revokes the token |
| `GET` | `/api/v1/events` | bearer | 200 `[Event]` | Events the caller **organizes** |
| `POST` | `/api/v1/events` | bearer | 201 `Event` | Body `{"event":{…}}`; `organizer_id` is always the caller |
| `GET` | `/api/v1/events/:id` | bearer | 200 `Event` | Readable by any signed-in user |
| `PUT`/`PATCH` | `/api/v1/events/:id` | bearer | 200 `Event` | **Organizer only** — 403 otherwise |
| `DELETE` | `/api/v1/events/:id` | bearer | 204 | **Organizer only** — 403 otherwise |
| `POST` | `/api/v1/events/add_user_to_events` | bearer | 201 `EventUser` | `event_id` as a query or form parameter |
| `GET` | `/api/v1/events/get_events` | bearer | 200 `[Event]` | Upcoming events the caller neither organizes nor has joined |
| `GET` | `/api/v1/events/joined_events` | bearer | 200 `[Event]` | Events the caller has joined |

### Resource shapes

```jsonc
// Event
{
  "id": 7,
  "name": "Zero Downtime Migrations",
  "description": "Shipping schema changes without a maintenance window.",
  "date": "2026-11-02T18:00:00.000Z",   // ISO 8601, UTC
  "location": "York",
  "organizer_id": 1
}

// EventUser (the attendance record)
{ "id": 7, "user_id": 2, "event_id": 4 }

// User
{ "id": 1, "email": "ada@example.com", "name": "Ada Lovelace" }
```

`User` never includes `encrypted_password`, `jti` or the password-reset columns.

## Pagination

Every list endpoint accepts `page` (default 1) and `per_page` (default 50,
maximum 100) and answers with:

```
X-Total-Count: 2
X-Page: 1
X-Per-Page: 2
```

The body stays a bare JSON array so existing clients keep working unchanged.
Out-of-range pages return `200 []`, not 404.

## Changes made during the uplift

All of these are corrections. The first two are security fixes; the rest are
protocol violations or wrong status codes. None of them requires a change in
`event_management_FE` — but the last one is a limit the client does not yet
respect.

| Endpoint | Was | Is | Why |
|---|---|---|---|
| `PUT`/`PATCH`/`DELETE /api/v1/events/:id` | 200/204 for **any** signed-in user, and `PUT` reassigned `organizer_id` to the caller | 403 unless the caller is the organizer | Anyone could edit, take over or destroy anyone's event |
| `POST /api/v1/events` with `organizer_id` in the body | the value was ignored only by accident | explicitly ignored; the caller is always the organizer | Defence in depth |
| `GET /api/v1/events/:id`, missing id | **200** with the raw exception string as the body | 404 `{"errors":["Event not found"]}` | Wrong status, and it leaked internals |
| `POST .../add_user_to_events`, missing event | 422 `"Event Not Found"` (a bare JSON string) | 404 `{"errors":["Event not found"]}` | Consistent envelope |
| `POST .../add_user_to_events`, no `event_id` | **200** with the raw exception string | 400 `{"errors":["The following param is missing…"]}` | Wrong status, and it leaked internals |
| `POST .../add_user_to_events` by the organizer | 201 — the organizer joined their own event | 403 | The event never appears in the joinable list, so the row was unreachable |
| Empty list responses | **204** with a JSON body, which Rack discards — clients received `""` | 200 `[]` | RFC 9110 forbids a body on 204 |
| Validation errors on events | `{"name":["can't be blank"]}` | `{"attributes_errors":{"name":[…]}}` | One error envelope across the API |
| All list endpoints | unbounded — 20,000 events meant 20,000 rows in one response | capped at 100, default 50 | See the Scalability section of the README |

### For the `event_management_FE` maintainer

Three notes, in order of importance:

1. **List endpoints are now paginated.** The client calls `/api/v1/events`,
   `/get_events` and `/joined_events` with no parameters and renders
   `response.data` directly. That still works and still returns an array, but it
   is now the first 50 rows rather than all of them. The client should read
   `X-Total-Count` and page, or pass `per_page`.
2. **Empty lists now return `200 []` instead of `204`.** This is a fix for the
   client's benefit: `204` made axios hand it `""`, and `"".length` being `0` was
   the only reason the "no events" branch rendered at all. `[]` is what the code
   already expects.
3. **The client sends a bare `Authorization` header with no scheme handling.**
   `src/services/api.js` stores whatever `response.headers["authorization"]`
   contained and sends it back verbatim. That is correct — the value already
   starts with `Bearer ` — but it is worth a comment, because a future
   "helpfully" prefixing `Bearer ` would double it.

One client-side bug noticed while writing this contract, unrelated to the API:
`SignIn.js` binds its inputs to `formData.email` / `formData.password`, but the
state is nested under `formData.user`. The fields are therefore permanently
uncontrolled-with-`undefined`; typing still works because `handleChange` writes
to the right place, but React logs a controlled/uncontrolled warning.
