# washbinpartner

The Washbin partner app: the professionals who take the bookings the customer
app creates. Talks to the same NestJS API as `apps/washbinapp`, through the
`partner-auth` and `partners` modules.

## Running it

```sh
flutter run --dart-define=ENV=development
```

See [docs/environments.md](docs/environments.md) for pointing a build at a
local, staging or production API — and for the extra define a physical device
needs.

## How it fits together

See [docs/architecture.md](docs/architecture.md): the session, the two tokens,
and how a partner's backend status decides which app they get.

## Tests

```sh
flutter test
```

They run the real object graph over a scripted API (`test/support/fake_backend.dart`)
and a Firebase stand-in, so sign-in, status routing and sign-out are exercised
end to end without a network or a Firebase project.
