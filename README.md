# En til?

Native Danish iPhone party board game, iOS 18+. Implementation in progress from the approved [specification](docs/SPECIFICATION.md); historical discovery is archived. Everything is local; no hosted resources have been created.

- `ios/`: SwiftUI app, native controls, secure guest session, StoreKit client and XcodeGen project.
- `backend/`: TypeScript Worker, SQLite Durable Object per room, versioned commands, private snapshots, D1 migrations and tests.
- `content/`: local-only question drafts awaiting human review.
- `design/references/`: all six approved sheets, 26 concepts.

Run `pnpm install`, then `pnpm check`. For the local service, run `pnpm exec wrangler d1 migrations apply en-til-local --local --config backend/wrangler.jsonc`, then `pnpm dev`. Generate the native project with `cd ios && xcodegen generate`. The Debug simulator endpoint is `http://127.0.0.1:8787`; physical-device and release endpoints require configuration. Full Xcode is needed to build SwiftUI.

The content release gate (`pnpm exec tsx scripts/validate-content.ts --release`) intentionally fails until required human-reviewed content exists. No purchase or deployment is enabled by placeholder identifiers. See [handoff](PROJECT_HANDOFF.md), [asset provenance](docs/ASSET_PROVENANCE.md), and [verification](docs/VERIFICATION.md).

Local integration checks (service running): `pnpm test:http`, `pnpm test:ws`, `pnpm test:rates`. `pnpm test:recovery` starts an isolated local Worker on port 8791 and tests two process restarts. `pnpm test:load` creates 100 local rooms with 800 WebSockets. These scripts refuse/use local endpoints; no production load test has run.

Content review starts at [batch 001](content/review/batch-001.md). The app remains a development implementation pending full iOS build, visual/accessibility/device review, Apple configuration, and the rest of the content.
