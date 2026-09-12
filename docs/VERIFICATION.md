# Verification record — 10 September 2026

This is an implementation checkpoint, not release approval.

## Executed locally

- Backend TypeScript strict check passes.
- Content schema check: 20 valid DRAFT questions, 0 human-approved; release count/review gate intentionally fails.
- 29 automated engine/RPC tests pass. Tests cover independent scoring, closest-guess ties, overshoot/shared winners, deadline equality, partial timeout scoring, stale/duplicate commands, privacy projection, away/return, host transfer, eight-seat limits/unique identities, late arrivals, room expiry, countdown, settings/adult checks, opt-outs and personal-only fallback.
- Local HTTP integration passes sessions, create retries, lowercase lookup, eight-player admission, authorization failures, setting/readiness/start, personal/factual path, answer/backing locks and persisted snapshot restoration.
- Local rate-limit test rejects five excess session requests after the configured 30-per-minute threshold.
- Local WebSocket test passes authentication, snapshot delivery, acknowledgement and same-seat disconnect/reconnect.
- Actual local load: 100 rooms, 800 simultaneous open WebSockets, 4,428 HTTP requests, 55.49 seconds; p50 107.56ms, p95 143.69ms, p99 170.97ms. See test-results/local-load-2026-09-10.json. This is Miniflare on this Mac; it does NOT establish Cloudflare capacity, edge latency or cost.
- Two actual local Worker process restarts pass: persisted session/room/round/results, replay of the final scoring command, and alarm recovery without double scoring.
- Worker dry-run bundle succeeds (no deployment).
- XcodeGen project generation succeeds.
- Swift 6 local type-check passes for wire models, Keychain storage, networking, DEBUG fixtures, StoreKit manager and reusable SwiftUI design components against the installed macOS SDK. The font's PostScript names were inspected; Fraunces-Regular exists.
- Shared SwiftUI typography/character/control render was inspected using ImageRenderer on macOS; this is a component review, not an iPhone screenshot.
- All app/test Swift sources pass syntax parsing. This is NOT an iOS build.

## Not yet established

- Full iOS application build, simulator execution and hosted screenshot outputs. No full Xcode is installed; manual Codemagic checkpoint is prepared but not started.
- All 26 reference comparisons, small iPhone/large text/VoiceOver/keyboard matrix, eight-player visual readability and final animation/character/pack art approval.
- Real-device audio/haptics/touch/pacing, and a real group playtest.
- Apple sandbox purchase/restore/pending/cancellation/refund/notification flows, real product prices and signed production config.
- 750 reviewed questions. Only the first 20-question batch exists; human Danish/source/tone review is pending.
- Production load/cost/monitoring/deploy recovery, private GitHub/Codemagic connection, support/privacy publication, name clearance, signing, age rating and App Store review.

Run commands and detailed implementation limitations are recorded in README.md, HOSTED_BUILDS.md and PRIVACY_AND_OPERATIONS.md. Future work must update this record with actual outputs, not assumptions.

## First hosted iOS checkpoint

The app compiled on Xcode 26.6 / iPhone 17 / iOS 26.5. One Swift Testing contract test and two XCTest UI tests passed; xcodebuild printed TEST SUCCEEDED. The enclosing Actions run was cancelled around completion by the agent and is not green. Thirteen screenshots were inspected; follow-up fixes and outstanding visual checks are in [NATIVE_REVIEW.md](NATIVE_REVIEW.md). This supersedes earlier statements that no full iOS build has run.

Follow-up run https://github.com/nick7167/en-til/actions/runs/34504392490 completed successfully on commit 9c15017. All three native tests passed, including complete normalized code entry, enabled number-guess confirmation, and visibility of the own board position. Updated screenshots confirm the fixes; the keyboard screenshot contains the simulator first-use tutorial and is not a clean keyboard reference.

## Reference checkpoint — 12 September 2026
GitHub Actions run 34696177984 passed on commit 92e7225 using the pinned standard macOS/Xcode runner. All three native tests passed, including 26 approved-reference captures and lowercase room-code keyboard/accessibility normalization. Local `pnpm check`, Swift syntax parsing and `git diff --check` passed. Screenshots are being compared; passing tests does not establish pixel-perfect fidelity. Subsequent board-background/menu/picker adjustments require the next checkpoint.

Further green native checkpoints: 34697301308 (d44fcba), 34697872872 (eea9fa0), and 34710744987 (ee21aa2). These include 26 reference routes, eight-player captures, and the keyboard check. Backend/content CI also passed at 1591681. The next checkpoint adds assertions for selecting the last friend in a full room and reaching actions at accessibility XXXL text size.

`python3 scripts/check-native-assets.py` now runs before native compilation. Its failure path was exercised with a temporary missing-image reference; the guard rejected it, then passed with the probe removed. This caught the absent compact bundle artwork, now committed. Dynamic image-name families still require screenshot review.

## 13 September visual/accessibility continuation
Run 34712298330 passed four native tests at 108bcde in 309.444 seconds. This includes default-size full-room selection and accessibility XXXL captures. Manual review revealed that hittability can pass with a partially visible control; the tightened follow-up checks full control bounds and confirms backing at large text sizes. One-column accessibility player grids and separate navigation space address the reviewed wrapping/overlap. The reference-derived ice asset passes its original-hero preservation assertion. These follow-up changes await their hosted checkpoint.
