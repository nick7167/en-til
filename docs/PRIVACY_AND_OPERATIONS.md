# Privacy and operating notes — implementation draft

No production service has been deployed. These notes describe intended data handling and the local code, not legal approval or a completed public privacy policy.

## Data and active deletion

An accountless installation has an opaque session ID and a random bearer token. D1 stores its SHA-256 hash; the native client stores the token in Keychain using a this-device-only accessibility class. Names, characters, presence, current choices and scores reside in the room object, not player-history analytics. The only long-term question history is question IDs associated with the host installation.

Personal yes/no responses are persisted privately until aggregation so a restart can recover correctly. Aggregation deletes the player-to-response map before guessing starts, and scoring clears it again. Skip identities are never published. Aggregates can permit inference, especially in small groups. Do not promise absolute anonymity.

Rooms expire 30 minutes after every player disconnects, including abandoned initializations. The room mapping and active room storage are deleted by the alarm. Reports and verified purchases are separate D1 records. Logs must exclude tokens, request bodies, private choices, names, and report notes. Aggregate technical-failure counters use fixed event names only.

## Provider recovery is separate from active deletion

Cloudflare's SQLite Durable Object storage offers recovery to points in the prior 30 days: https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/ (checked 10 September 2026). Deleting a response from active state is not a promise that historical provider recovery copies disappear immediately. D1 Time Travel is described at https://developers.cloudflare.com/d1/reference/time-travel/; confirm the deployed account's retention/settings before the public policy is approved. D1 does not receive personal yes/no responses.

Before launch, settle retention periods for guest sessions, purchase records, reports, question IDs, provider backups and any operational access logs. Configure deletion/support requests and an authenticated internal process. No legal retention period or GDPR compliance conclusion is asserted here.

## Deployment boundaries

The committed Wrangler config is LOCAL ONLY. `database_id: local-only`, no workers.dev route, development draft catalogue. No production/test account resource IDs or secrets. Provision separate test and production namespaces/databases/configs only with explicit permission. Production must use reviewed content and fail closed without it. Match catalogue is serialized into room state, preserving an in-flight version across compatible code/content deployments. Schema-breaking changes need migration testing against persisted v1 fixtures.

Apple configuration: APPLE_PRIVATE_KEY, APPLE_KEY_ID, APPLE_ISSUER_ID, APPLE_BUNDLE_ID, APPLE_APP_ID (production), and APPLE_ROOT_CERTIFICATES (JSON array of base64 DER roots from Apple PKI). Never commit values. Sandbox and Production are separate record keys and verifier environments, not fallback alternatives. Configure /v1/apple/notifications for each environment only after verified testing. The server refreshes transaction info with Apple before granting access, so old signed transaction replay cannot reverse a refund. Signed notifications update existing ownership without granting a new installation rights. Retry and sandbox end-to-end acceptance remain unverified without Apple configuration.

DISABLED=true is the emergency entry-point control; restart/resume behavior must be exercised before production. Existing sockets reject their next command while disabled. Alarms still resolve committed rounds; this is not an in-game pause. No mid-round pause feature is offered.

Creation, lookup, session creation and reports have rate-limited entry points. Reactions are room-limited and player-limited. Confirm edge rate limits under distributed traffic; local Miniflare measurements cannot establish regional limits or production capacity. Watch D1 read/write counts, DO duration/storage, errors, active sockets, and invocation volume. Cloudflare plan allowances are not a spending cap. Dashboard alerts and budget review remain setup tasks.

## Release dependencies

Support contact, final controller identity/address, public support/privacy URLs, privacy disclosures, age rating, name clearance, Apple review of adult/drinking content, product IDs and localized prices must be reviewed before distribution. No website or App Store publication is enabled here.
