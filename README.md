# Pocket — personal finance tracker

A single-user starter with a Go API, a responsive Next.js dashboard, and a Flutter mobile client. Track EUR accounts, income and expenses, fixed categories, and monthly totals. Create accounts with opening balances, search transactions on the web, and delete transactions in either client.

## Layout

- `backend/`: Go standard-library HTTP API with atomic JSON-file persistence; no external service or credentials required.
- `web/`: Next.js App Router, React and TypeScript. `/api/*` is forwarded to Go by the Next.js server.
- `mobile/`: Flutter client using the same API. Android and iOS platform projects are included.

Money is represented as signed integer cents in the API: positive amounts are income, negative amounts are expenses. All balances use EUR; there is no currency conversion. New workspaces have one empty account and six categories, with no sample transactions.

## Run locally

Use Go 1.24 or newer, Node.js 20.9 or newer, and Flutter 3.35+ (Dart 3.10+). Validated here with Go 1.27.2, Node.js 24.19.0, and Flutter 3.47.7. In this cloud machine the installed Go binary is `/workspace/toolchains/go/bin/go`; `/usr/bin/go` is an unrelated program.

```sh
export PATH=/workspace/toolchains/go/bin:$PATH
export GOCACHE=/workspace/.cache/finance/go
cd /workspace/finance-tracker/backend
go run .
```

In another terminal:

```sh
cd /workspace/finance-tracker/web
npm ci
npm run dev
```

Web listens on port 3000 and API on `127.0.0.1:8080`. Open the web app in your local development browser. The cloud onboarding UI does not provide a web preview. Optional `API_URL` sets the web server's upstream URL. API `LISTEN_ADDR` changes its bind address; `DATA_FILE` changes the JSON storage path (default `backend/data/finance.json` when started from `backend/`). Never run multiple API processes against the same data file.

## Mobile

Flutter artifact downloads require `storage.googleapis.com`; packages require `pub.dev` and `storage.googleapis.com`. Flutter analysis and two widget tests pass in this cloud machine. Device builds and on-device behavior have not been verified: no Android SDK/emulator is installed, and iOS builds require macOS/Xcode.

The Android and iOS launchers are already included. Install the Android SDK and an emulator, or connect a supported device, before running the app. In this cloud machine, activate the installed tools with `source /workspace/finance-tracker/scripts/cloud-env.sh`.

```sh
cd /workspace/finance-tracker/mobile
flutter pub get
flutter analyze
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

`10.0.2.2` reaches the development machine from the Android emulator. For the iOS simulator use `http://127.0.0.1:8080`; iOS requires macOS and Xcode. A physical phone needs a reachable machine address and API `LISTEN_ADDR=0.0.0.0:8080` on a trusted development network. The included Android project has Internet permission and a debug-only cleartext exception; iOS has a local-network ATS exception for HTTP development. Use HTTPS for deployed clients. The web client uses the Next.js proxy; Flutter web CORS is not configured.

## Validation

```sh
cd backend
go test -race ./...
go build ./...
cd ../web
npm run typecheck
npm run build
```

Run `bash scripts/check.sh` to run the complete check set with cloud caches configured. For a fresh cloud machine, `bash scripts/setup-cloud.sh` installs pinned Go and Flutter toolchains, installs locked dependencies, and runs the checks. Tool activation is in `scripts/cloud-env.sh`; source it in each shell.

The API test exercises invalid inputs, persistence after reopening the store, account creation, and transaction deletion. Two Flutter widget tests check transaction entry and balance calculation through the API client, plus a recoverable API failure. A real Chromium smoke check was also run against the production web server: account creation, expense entry, balance calculation, persistence after reload, deletion, and mobile viewport layout.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/health` | Readiness |
| GET | `/api/data` | Accounts, categories and transactions |
| POST | `/api/accounts` | `{ "name": "Savings", "opening": 10000 }` |
| POST | `/api/transactions` | `{ "accountId": "1", "categoryId": "1", "description": "Food", "amount": -1250, "date": "2026-10-18" }` |
| DELETE | `/api/transactions/{id}` | Delete a transaction |

This starter has no authentication, account transfers, recurring transactions, or bank integration. Keep it local until authentication and a deployment data strategy are implemented. Back up the data file; it contains personal financial records. Native Android/iOS builds and on-device testing remain outstanding.
