# Partner app architecture (Phases 1-2)

## The shape

```
main.dart
  └── WashbinPartnerApp          builds AppServices, starts the session
        ├── AppServicesScope    repositories, for screens that need one
        └── SessionScope        the session, rebuilding what depends on it
              └── MaterialApp
                    └── AppGate  picks the app from the session and the partner
```

Deliberately the same shape as `apps/washbinapp`. The two apps are separate
binaries with separate backend modules, but one person maintains both, and a
reader who knows one should not have to learn the other.

## Authentication: two tokens, not one

Firebase and the Washbin API each issue a token, and they are not
interchangeable:

```
phone number
   → Firebase sends an SMS, partner types the code
   → Firebase ID token  (proves the number is theirs)
   → POST /partner-auth/phone
   → Washbin access token  (a JWT with a `type: 'partner'` claim)
   → Authorization: Bearer <washbin token>  on every other call
```

`PartnerAuthGuard` on the server verifies the **Washbin** token, and rejects a
customer token outright. The Firebase ID token appears in exactly one place —
the body of the exchange above — and is never sent as a bearer header.

Firebase owns persistence. Its SDK already stores the phone session securely,
so the Washbin token is held in memory only (`AccessTokenStore`) and a cold
start mints a fresh one by replaying the exchange. There is no refresh-token
logic to maintain and no second copy of a credential on disk.

## Two questions, asked in order

The gate asks two separate questions, and keeping them separate is the point:

**1. Is there a session?** — `SessionStatus`, owned by sign-in.

| Status | Meaning | What the partner sees |
|---|---|---|
| `initializing` | startup is deciding | splash |
| `unauthenticated` | no session | phone number entry |
| `registrationRequired` | number verified, no partner account yet | business details |
| `authenticated` | signed in, token in hand | question 2 decides |
| `blocked` | number verified, server refused a token | suspended screen |
| `failed` | server unreachable at startup | retry |

**2. What is this partner allowed to do?** — `Partner.stage`, derived from the
backend's `status` and `verificationStatus`.

| Stage | Derived from | What the partner sees |
|---|---|---|
| `profileIncomplete` | verification `pending` | onboarding checklist |
| `pendingApproval` | verification `submitted` | onboarding, in its waiting form |
| `rejected` | verification `rejected` | onboarding, with the reason |
| `suspended` | account `status: suspended` | a closed door |
| `approved` | verification `verified`, not suspended | the app shell |

Suspension outranks verification: a suspended partner who happens to be
verified is still suspended. `inactive` is not a gate — a partner who has
stepped away keeps the app, they are simply not matched.

A new backend partner state is a new arm of the second switch. Sign-in does not
move.

### Two names that look alike

`SessionStatus.registrationRequired` and `PartnerStage.profileIncomplete` are
different states and neither implies the other:

- **`registrationRequired`** — the API answered `PROFILE_REQUIRED`. There is no
  partner record at all; the number is verified and nothing else exists.
- **`profileIncomplete`** — a partner record exists, and its owner has not
  finished onboarding.

Phase 1 called the first one `profileIncomplete` too. It was renamed when the
second appeared, because the two would otherwise read identically at every call
site while meaning opposite things about whether an account exists.

## Onboarding, and why it is one screen

`pending`, `submitted` and `rejected` all route to `OnboardingScreen`. They are
the same two tasks — finish the profile, choose the services — seen at
different points, so what varies between them is the status card at the top and
whether submitting is offered. Three screens would have triplicated a
checklist.

Suspension is the exception: it goes to `PartnerStatusScreen` instead, because
there is nothing a suspended partner could edit that would change the decision,
and offering the form would suggest otherwise.

```
profileIncomplete ──edit profile──┐
                                  ├─> submit-for-review ──> pendingApproval
rejected ─────────choose services─┘                              │
   ^                                                    Washbin reviews
   └──────────────── rejected, with a reason ───────────────┤
                                                        approved ──> app shell
```

### Where "complete" is decided

The server owns the rule: `POST /partners/me/submit-for-review` refuses an
incomplete profile or a partner with no active services, naming what is
missing. The app keeps a second copy in `ProfileCompleteness` purely so the
checklist can show what is outstanding while the partner fills the form in —
finding out from a rejected submit would be a worse way to learn it.

**The two must stay in step**: `REQUIRED_PROFILE_FIELDS` in
`api/src/partners/partners.service.ts` and `ProfileRequirement` in
`lib/features/partner/domain/profile_completeness.dart`. If they drift, the
submit button offers itself and the server refuses — which the app surfaces
verbatim rather than swallowing, so the drift is visible rather than silent.

## Blocking access to work

Live job requests will live behind `_ApprovedFlow` and nowhere else. An
unapproved partner is not steered away from them — the screens are never built,
so there is no route to push, restore, or link to. The same is true the moment
a suspension lands mid-session: the branch is torn down with whatever was
pushed over it.

## Choosing services

`partner_services` is a join row per (partner, service), and `isActive` is why
the row is kept rather than deleted. The API offers a partner no delete at all:

| Partner action | Request | Why |
|---|---|---|
| select a new service | `POST /partner-services/me` | no row exists yet |
| select a paused one | `PATCH /partner-services/me/:id` | the unique index on `(partnerId, serviceId)` refuses a second row |
| clear a service | `PATCH /partner-services/me/:id` | pausing keeps the history; assignment skips an inactive row exactly as it would a missing one |

Each tap is its own write, applied immediately. There is no Save button,
because there is no batch route behind one — a failed save would leave a
half-applied list and no way to say so.

### Why `blocked` is not `unauthenticated`

The API refuses a suspended partner a token at all — `PartnerAuthService`
throws 403 before the account is even looked up. Sending them back to the
number entry would ask them to retype a number that is not the problem and
refuse it again. So the Firebase session is kept, the gate explains, and
**Check again** re-runs the exchange — which is also how a lifted suspension
lets them back in without a new SMS.

`failed` is likewise distinct from `unauthenticated`: a network blip must not
cost the partner their session and force a new OTP.

## Route protection

`AppGate` derives the widget tree from the session. Protection is structural
rather than checked: while a partner is unapproved, the app shell is not built
at all, so there is no route to push, restore, or link to. A suspension that
lands mid-session tears the shell down with the branch rather than leaving a
job screen sitting above the status screen.

Sign-in is a short wizard, so it gets its own nested `Navigator`, discarded
with its branch when the session resolves.

## Network

Every HTTP call leaves through `ApiClient`. It attaches the bearer token when
there is one, maps failures to `ApiErrorKind`, and reports a rejected token to
the session so it can end. A 401 on a call that carried *no* token is not
treated as a dead session — signing out over it would loop.

Request logging records method, path, status and duration, and only in debug
builds outside production. Headers, request bodies and response bodies are
never passed to the logger, so tokens, OTP codes and personal data cannot be
logged by mistake.

## Reading and writing the partner

Everything goes through `/partners/me`, which takes the partner id from the
bearer token. No path in this app names a partner id, deliberately:
`PATCH /partners/:id` is unguarded on the server *and* accepts `authUserId` and
`phone`, so using it from the app would hand the client the keys to any
account. `PATCH /partners/me` takes an explicit allow-list instead —
`verificationStatus` and `status` in the body are a 400, not a quiet
self-approval.

If that read fails for any reason other than a rejected token, the session
falls back to what the sign-in response already carried — business name, owner,
phone and verification status. A flaky profile read does not cost a session.
The one field the exchange omits is `status`, and a suspended partner never
reaches that code path: the exchange itself would have 403'd.

## State management

`ChangeNotifier` + `InheritedNotifier`, both from Flutter itself. No package was
added. This is the same shape `provider` wraps, so swapping one in later would
not change what any call site means.

## What Phases 1-2 deliberately leave out

The availability toggle, location tracking, incoming job offers, accept and
decline, the active service lifecycle, earnings, notifications, reviews and
payments. The Jobs and Bookings tabs exist and say so, because moving a tab
later moves every partner's muscle memory with it.

Two things from the Phase 2 brief are also not built, both for the same reason
— there is no file storage behind the API:

- **Profile photo upload.** `profileImage` exists on the schema and a photo set
  elsewhere is displayed, but nothing in the app can put one there.
- **KYC document upload.** `Partner.documents[]` exists with a per-document
  status, and no endpoint accepts a file. Verification is therefore a decision
  Washbin makes out of band, which is what `submit-for-review` asks for.
