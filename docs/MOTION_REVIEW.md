# Native motion review — 20 September 2026

Code review and simulator assertions do not establish physical-device pacing or frame-rate quality.

## Implemented

The final reveal stage now presents a dedicated visible board instead of appending it below all result rows. Tokens start at their previous score and move to the authoritative result using native matched geometry (0.85 seconds after a 120 ms layout delay). The board scroll follows the local player. No server score or deadline changes.

Reduce Motion and accessibility text sizes show final positions immediately. Cancelling the view cancels the pending delay; the regular board always uses authoritative positions. The movement snapshot fixture checks that the local player reaches field 6.

Native verification: pending run 35524844518 at 8a0ff4d.

## Still open

- Inspect the new movement screenshot and native test results.
- Review movement on a physical phone, including interruption and late-stage reconnection.
- Review result-stage insertions and perceived pacing before adding more transitions.

Overall motion approval remains open. Existing button press feedback and scrolling respect Reduce Motion. Web-specific CSS guidance was not treated as a SwiftUI requirement.
