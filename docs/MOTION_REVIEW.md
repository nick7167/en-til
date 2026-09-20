# Native motion review — 20 September 2026

Code review and simulator assertions do not establish physical-device pacing or frame-rate quality.

## Implemented

The final reveal stage now presents a dedicated visible board instead of appending it below all result rows. Tokens start at their previous score and move to the authoritative result using native matched geometry (0.85 seconds after a 120 ms layout delay). The board scroll follows the local player. No server score or deadline changes.

Reduce Motion and accessibility text sizes show final positions immediately. Cancelling the view cancels the pending delay; the regular board always uses authoritative positions. The movement snapshot fixture checks that the local player reaches field 6.

Native verification: app compiled at 8a0ff4d in run 35524844518; five existing UI tests and both contract tests passed. The new fixture was absent from Xcode resources; regeneration fixed it. Focused run 35525670758 at 8e7744d passed the additional-screen test (82.395 seconds), including the final field-6 assertion. The movement screenshot was inspected in build/visual-twentythird.

## Still open

- Review movement on a physical phone, including interruption and late-stage reconnection.
- Review result-stage insertions and perceived pacing before adding more transitions.

Overall motion approval remains open. Existing button press feedback and scrolling respect Reduce Motion. Web-specific CSS guidance was not treated as a SwiftUI requirement.
