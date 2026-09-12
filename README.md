# En til?

Native Danish iPhone party board game, iOS 18+. Implementation in progress from the approved [specification](docs/SPECIFICATION.md); historical discovery is archived. Source is hosted publicly at https://github.com/nick7167/en-til. No backend is deployed. GitHub Actions runs backend checks; the native simulator checkpoint is manual.

- `ios/`: SwiftUI app, native controls, secure guest session, StoreKit client and XcodeGen project.
- `backend/`: TypeScript Worker, SQLite Durable Object per room, versioned commands, private snapshots, D1 migrations and tests.
- `content/`: question drafts awaiting human review.
- `design/references/`: all six approved sheets, 26 concepts.

Run `pnpm install`, then `pnpm check`. For the local service, run `pnpm exec wrangler d1 migrations apply en-til-local --local --config backend/wrangler.jsonc`, then `pnpm dev`. Generate the native project with `cd ios && xcodegen generate`. The Debug simulator endpoint is `http://127.0.0.1:8787`; physical-device and release endpoints require configuration. Full Xcode is needed to build SwiftUI.

The content release gate (`pnpm exec tsx scripts/validate-content.ts --release`) intentionally fails until required human-reviewed content exists. No purchase or deployment is enabled by placeholder identifiers. See [handoff](PROJECT_HANDOFF.md), [asset provenance](docs/ASSET_PROVENANCE.md), and [verification](docs/VERIFICATION.md).

Local integration checks (service running): `pnpm test:http`, `pnpm test:ws`, `pnpm test:rates`. `pnpm test:recovery` starts an isolated local Worker on port 8791 and tests two process restarts. `pnpm test:load` creates 100 local rooms with 800 WebSockets. These scripts refuse/use local endpoints; no production load test has run.

Content review starts at [batch 001](content/review/batch-001.md). The app remains a development implementation with a passing hosted iOS build and four native tests; pending full visual/accessibility/device review, Apple configuration, and the rest of the content.

Local StoreKit visual testing: `ios/EnTilUITests/LaunchPacks.storekit` provides six non-consumable test packs at 29 DKK and the launch bundle at 99 DKK, using the Danish storefront. UI tests reset an Apple `SKTestSession` before launching and require loaded prices on detail/bundle captures. This configuration is in the test bundle only; it does not configure App Store products or establish server-verified ownership. Production still uses StoreKit product prices. Native verification of this setup and the latest ice/accessibility changes is pending.
