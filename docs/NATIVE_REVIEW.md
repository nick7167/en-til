# First native simulator review — 10 September 2026

Xcode 26.6, iPhone 17 / iOS 26.5, commit 9700291. Run: https://github.com/nick7167/en-til/actions/runs/34503098046.

The complete app and test targets compiled. The command-encoding contract test and both UI tests passed; xcodebuild printed TEST SUCCEEDED. The Actions run itself is marked cancelled because the agent requested cancellation around completion after mistaking the long simulator setup for a possible stall. Do not label this a green Actions run. No compiler failure caused the delay: compilation finished in about one minute, followed by several minutes of simulator setup and UI automation.

Thirteen screenshots were exported and reviewed locally. Their original manifest and images are in ignored build/native-second/screenshots; the hosted artifact has one-day retention. This is fixture testing, not live multiplayer testing.

## Findings

- Home, lobby, factual answer, backing, reveal, finale, away and late-arrival screens render with the intended palette, Fraunces and characters. Home create/join controls are visible at this device size.
- The code-entry screenshot contained KMX after the test typed k7mx. The old test checked only button hit testing. Normalization was moved into the binding setter, and the test now requires K7MX and an enabled button.
- Personal guess numbers were squeezed out by a horizontal choice layout in narrow grid cells. Dedicated large number buttons replace it; tests check hit targets and selecting a guess.
- The board initially displayed empty spaces 8–12 while players were at 1–2. Positioned scroll anchors were replaced by real fixed-height rows and a bottom default anchor; a test checks the own-position element is visible.
- Disabled primary actions previously looked enabled. The button style now dims them using the native enabled environment.

These corrections are in 9c15017. The follow-up run passed: https://github.com/nick7167/en-til/actions/runs/34504392490. All three tests passed and thirteen screenshots were exported. Visual inspection confirms the complete K7MX code, readable/selectable numbers, and visible player positions on the board. The code screenshot includes the simulator’s first-use keyboard tutorial; repeat a clean keyboard capture in the broader device matrix.

## Remaining visual work

This is not approval against all 26 concepts. The board still needs illustrated surroundings, stronger winding composition and movement polish. Several play screens need the layered scene details in the references. The waiting illustration occupies too much height before the player completion list. Title weight, spacing, small screens, eight-player layouts, accessibility text sizes and all settings/purchase screens still need review. The development app icon is provisional. Nicklas has not approved these native renders.
