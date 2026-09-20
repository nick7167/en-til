# Native motion review — 20 September 2026

Code review only; this is not a device pacing or frame-rate approval.

| Before | After needed | Why |
| --- | --- | --- |
| `ios/EnTil/RoomView.swift:200` inserts `WindingBoard` only at reveal stage 3, when scores already show the destination. `ios/EnTil/BoardView.swift:84` only animates subsequent own-score changes. | Present an explicit previous-to-current board transition during the server's movement stage, with reduced-motion support and immediate current-state recovery. | The normal reveal path does not demonstrate actual token movement. The existing scroll animation is insufficient evidence. |
| `ios/EnTil/RoomView.swift:197` inserts result rows and points at server stages without local transitions. | Review a short, restrained transition for these infrequent stage changes, keeping server stage timing authoritative. | Abrupt insertion can shift the scene; assess native recordings before choosing motion. |

**Origin, physicality and cohesion:** board movement remains unfinished. Do not claim that passing screenshot/live-match tests establishes smoothness.

**Accessibility:** `LoungeButtonStyle` and the existing board-scroll animation already respect Reduce Motion. Preserve this in future changes.

**Verdict: Block overall motion approval.** Press feedback is present; reveal/board movement and physical-device pacing still need implementation and verification. Web-specific CSS rules from the review skill are not applied as SwiftUI requirements.

Implementation: movement stage now has its own visible board, with opt-in previous-to-current token positions using matchedGeometryEffect (0.85 seconds). Reduce Motion and accessibility text show final positions immediately. Server timing and scores remain unchanged. A movement fixture asserts the final own position. Native verification pending; physical-device pacing remains open.
