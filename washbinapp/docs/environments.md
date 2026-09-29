# Configuring the backend URL

The app picks its API host at **compile time** from `--dart-define`. Nothing is
hardcoded in a screen, and no secrets live here — these are build settings.
See `lib/core/config/app_config.dart`.

| Define | Values | Default |
|---|---|---|
| `ENV` | `development` \| `staging` \| `production` | `production` |
| `API_BASE_URL` | any origin, e.g. `http://192.168.1.5:3000` | per-environment default below |

`API_BASE_URL` always wins when set. Anything unrecognised in `ENV` is treated
as production, so a typo can never silently point a release build at a dev
server.

## Per-environment defaults

| `ENV` | Default base URL |
|---|---|
| `development` | `http://10.0.2.2:3000` on Android, `http://localhost:3000` elsewhere |
| `staging` | `https://washbin-api-staging.vercel.app` |
| `production` | `https://washbinapi.vercel.app/` |

## Running against a local API

`localhost` on a device means *the device itself*, not your machine. Each
target reaches the host differently:

**Android emulator** — `10.0.2.2` is the emulator's alias for the host. This is
the default, so no define is needed:

```sh
flutter run --dart-define=ENV=development
```

**iOS simulator** — shares the host's network stack, so `localhost` works. Also
the default:

```sh
flutter run --dart-define=ENV=development
```

**Physical device (Android or iOS)** — must use your machine's LAN address, and
the phone must be on the same Wi-Fi. Find it with `ipconfig getifaddr en0` on
macOS:

```sh
flutter run \
  --dart-define=ENV=development \
  --dart-define=API_BASE_URL=http://192.168.1.5:3000
```

Start the API with `pnpm start:dev` in `api/`, and make sure it is listening on
all interfaces (`0.0.0.0`) rather than only loopback.

**Staging / production**

```sh
flutter run  --dart-define=ENV=staging
flutter build apk --release --dart-define=ENV=production
```

## Cleartext HTTP

A local API is plain `http`, which Android blocks from API 28 onward. Debug
builds allow it via `android/app/src/debug/AndroidManifest.xml`; release builds
deliberately do not, so a production build cannot fall back to an unencrypted
connection.

## Verifying the connection

The Profile tab shows the active environment and base URL, with a **Check
backend connection** button that calls `GET /health`. Both are hidden in
production builds. Startup never pings the server — there is no product reason
to add a round trip to every cold launch.

## What is *not* configured here

Firebase. Its client configuration is read from
`android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`,
and switching Firebase projects means swapping those files, not a define.
