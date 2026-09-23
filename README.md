# En til?

Native Danish iPhone party board game, iOS 18+. Implementation in progress from the approved [specification](docs/SPECIFICATION.md); historical discovery is archived. Source is hosted publicly at https://github.com/nick7167/en-til. The isolated TestFlight beta backend is deployed at https://en-til-beta.nicklas-andreasen2000.workers.dev. It serves the 20 draft questions; this is not the release catalogue. GitHub Actions runs backend checks; the native simulator checkpoint is manual.

- `ios/`: SwiftUI app, native controls, secure guest session, StoreKit client and XcodeGen project.
- `backend/`: TypeScript Worker, SQLite Durable Object per room, versioned commands, private snapshots, D1 migrations and tests.
- `content/`: question drafts awaiting human review.
- `design/references/`: all six approved sheets, 26 concepts.

Run `pnpm install`, then `pnpm check`. For the local service, run `pnpm exec wrangler d1 migrations apply en-til-local --local --config backend/wrangler.jsonc`, then `pnpm dev`. Generate the native project with `cd ios && xcodegen generate`. The Debug simulator endpoint is `http://127.0.0.1:8787`; physical-device and release endpoints require configuration. Full Xcode is needed to build SwiftUI.

The content release gate (`pnpm exec tsx scripts/validate-content.ts --release`) intentionally fails until required human-reviewed content exists. No purchase or deployment is enabled by placeholder identifiers. See [handoff](PROJECT_HANDOFF.md), [asset provenance](docs/ASSET_PROVENANCE.md), and [verification](docs/VERIFICATION.md).

Local integration checks (service running): `pnpm test:http`, `pnpm test:ws`, `pnpm test:rates`. `pnpm test:recovery` starts an isolated local Worker on port 8791 and tests two process restarts. `pnpm test:load` creates 100 local rooms with 800 WebSockets. These scripts refuse/use local endpoints; no production load test has run.

Content review starts at [batch 001](content/review/batch-001.md). The app remains a development implementation with a passing hosted iOS build, two contract tests and six native UI tests; pending full visual/accessibility/device review, Apple configuration, and the rest of the content.

DEBUG screenshot fixtures display Danish target prices (29 DKK per pack, 99 DKK bundle) and disable purchase/restore calls. These are presentation fixtures, not StoreKit purchase tests. Production labels use actual StoreKit product prices; real purchase verification remains pending configuration. Experimental local StoreKit sessions/test plans were removed after hosted failures.

For faster screenshot review, download the `native-review` artifact (full-resolution JPEGs/text diagnostics), then run `python3 scripts/compare-reference-screens.py <download-folder>`. Comparisons preserve proportions by default; `--stretch` reproduces old normalized sheets. Original PNGs and failure videos remain in `native-checkpoint`.

The native UI suite also runs a real three-player match against the local Worker, including app reopening, joint winners, rematch and seat restoration. Start the local database/service above before running the full suite locally; GitHub Actions starts it automatically. Screenshot prices remain presentation fixtures, not purchase verification.

Simulator checks use local ad-hoc signing and simulator-only Keychain entitlements so live sessions use real secure storage. No Apple signing account is needed. The manual native workflow supports `scope=live` for focused integration retries; its default runs the full suite.

To play a TestFlight match without other people, create a room on your phone, then run:

```sh
ENTIL_TEST_URL=https://en-til-beta.nicklas-andreasen2000.workers.dev ENTIL_ALLOW_REMOTE_BETA=1 pnpm test:bots ROOM_CODE 2
```

Replace `ROOM_CODE` with its four-character code. Two visibly named test bots join, ready up, make synthetic answers, and back other players. The human host controls starting/rematches; bots do not buy packs, alter settings, or read hidden answers. Private answers are not logged. Leave them running while playing; Ctrl-C removes them, and they stop automatically after one hour. Up to seven bots are supported within the eight-player room limit. Run `pnpm test:bots --self-test` for their complete-match decision check. These companions test multiplayer behavior, not human question quality, purchases, or physical-device accessibility/audio/haptics.

For local checks, `ENTIL_TEST_URL` also supports another local port for HTTP, WebSocket, load, rate-limit, and bot scripts. For example, start `pnpm dev --port 8792` if port 8787 is occupied, and run `ENTIL_TEST_URL=http://127.0.0.1:8792 pnpm test:http`. Load/rate-limit checks reject remote targets.

To record a native gameplay session on the standard hosted runner, run `gh workflow run native.yml -f scope=live -f record=true`. The `gameplay-session` artifact contains the full silent simulator video and recorder log (seven-day retention). See [gameplay UX review](docs/GAMEPLAY_UX_REVIEW.md) for the reviewed session and proposed improvements.
