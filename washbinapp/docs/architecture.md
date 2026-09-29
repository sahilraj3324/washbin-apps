# Customer app architecture (Phase 1)

## The shape

```
main.dart
  └── WashbinApp                 builds AppServices, starts the session
        ├── AppServicesScope    repositories, for screens that need one
        └── SessionScope        the session, rebuilding what depends on it
              └── MaterialApp
                    └── AppGate  picks the app from the session status
```

## Authentication: two tokens, not one

Firebase and the Washbin API each issue a token, and they are not
interchangeable:

```
phone number
   → Firebase sends an SMS, customer types the code
   → Firebase ID token  (proves the number is theirs)
   → POST /customer-auth/phone
   → Washbin access token  (a JWT with a `type: 'customer'` claim)
   → Authorization: Bearer <washbin token>  on every other call
```

`CustomerAuthGuard` on the server verifies the **Washbin** token. Sending the
Firebase ID token to a guarded route would be rejected.

Firebase owns persistence. Its SDK already stores the phone session securely,
so the Washbin token is held in memory only (`AccessTokenStore`) and a cold
start mints a fresh one by replaying the exchange. There is no refresh-token
logic to maintain and no second copy of a credential on disk.

## Session states

`SessionController` is the only thing that decides who is signed in.

| Status | Meaning | What the customer sees |
|---|---|---|
| `initializing` | startup is deciding | splash |
| `unauthenticated` | no session | phone number entry |
| `profileIncomplete` | number verified, no Washbin account yet | name entry |
| `authenticated` | signed in, token in hand | the app shell |
| `failed` | server unreachable at startup | retry |

`profileIncomplete` is not a half-built profile on the server — the API requires
a name at creation, so an account that exists is always complete. It is the
`PROFILE_REQUIRED` 404: a verified number with no account behind it.

`failed` is deliberately distinct from `unauthenticated`. A network blip must
not cost the customer their session and force a new SMS.

## Route protection

`AppGate` derives the widget tree from the session status. Protection is
structural rather than checked: while signed out, the signed-in half of the app
is not built at all, so there is no route to push, restore, or link to.

Sign-in is a short wizard, so it gets its own nested `Navigator`. When the
session resolves, that navigator is discarded with its branch — a half-finished
sign-in can never be left sitting above the app.

## Network

Every HTTP call leaves through `ApiClient`. It attaches the bearer token when
there is one, maps failures to `ApiErrorKind`, and reports a rejected token to
the session so it can end. A 401 on a call that carried *no* token is not
treated as a dead session — signing out over it would loop.

Request logging records method, path, status and duration, and only in debug
builds outside production. Headers, request bodies and response bodies are
never passed to the logger, so tokens, OTP codes and personal data cannot be
logged by mistake.

## State management

`ChangeNotifier` + `InheritedNotifier`, both from Flutter itself. No package was
added. This is the same shape `provider` wraps, so swapping one in later would
not change what any call site means.
