# Text readability review — 21 September 2026

## Current treatment

The first pass (ac7a2fa, native run 35527839000) added opaque text backing. The user rejected its boxed appearance and formal supporting typography; that standalone-copy treatment is superseded.

- Supporting text and controls use the native rounded font. Fraunces display headings explicitly clear the inherited font design.
- Standalone copy uses small glyph shadows, without rectangular backplates or enlarged blurred backgrounds that can shade adjacent buttons.
- Cards, form fields and selected answers retain solid fills. Board numbers and pack subtitles retain full-opacity text.
- Shop and bundle screens retain the quieter original plain background.
- Private-round guidance is moved below the bright illustration, immediately above the answer choices.

## Verification

Full native run 35545264745 passed two contract tests and six UI tests, including a real multiplayer match. Its screenshot review identified the inherited-font and blurred-backdrop regressions, corrected in a8f1f5a.

Focused run 35588640948 passed all 26 reference captures and four accessibility XXXL captures; the executed-test log confirms TEST SUCCEEDED. Inspected all 30 captures under ignored build/visual-playful-final/review. Expressive headings are restored, rounded supporting copy is visible, lime buttons no longer have backdrop smudges, and home/join/finale artwork is sharper. That review found private guidance crossing the bright character; the subsequent position change at eb40493 passed run 35590245122 attempt 2. The final D01-private capture places the guidance on the dark sofa below the character, with clean controls and no rectangular backplate.

The 13 fixed palette contrast pairs pass at 4.5:1 or better. This does not establish contrast over arbitrary illustration pixels. Native screenshots are visual evidence for the captured states, not proof across all content, devices or text sizes. Physical-device readability, VoiceOver and final visual approval remain open.

Native run 35590245122 attempt 1 compiled but timed out launching the app in the reference test; the following large-text test stalled until the 30-minute job cancellation. No completed result bundle was exported. This is not passing evidence. Attempt 2 passed on that same commit: reference test 395.731 seconds, large-text test 43.481 seconds, and TEST SUCCEEDED confirmed. Final captures: build/visual-private-final/review.
