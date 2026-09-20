# Text readability review — 20 September 2026

## Changes

- A shared opaque ink backing protects exposed instructions, supporting copy, reports, reactions and pack copy. It follows wrapped text without covering the entire scene.
- The scene header has a dark gradient behind titles and navigation. Artwork remains visible in the body.
- Panels, player cards, settings surfaces and selected answers use opaque fills. Selected answers no longer allow bright art through a 10% lime fill.
- Disabled primary actions keep readable lilac text on a lounge background. Occupied-character and away-player names no longer fade with the whole card.
- Guest lobby settings are ordinary read-only information, not dimmed disabled buttons.
- Board numbers and pack subtitles no longer use translucent text.

## Screen sweep

| Screens | Text protection |
| --- | --- |
| Home | Backed tagline/shop link, opaque profile and actions |
| Code/name/character joining, profile | Header shading, input/card backgrounds, backed availability guidance |
| Host/guest lobby | Code plaque, solid player/settings panels, backed readiness explanation |
| Factual/private/guess/backing | Opaque answer controls, backed question/instructions, solid timer and pack label |
| Waiting, away, late arrivals | Backed supporting text; opaque completion/player lists |
| Reveal, movement, board, finale | Opaque results/name labels; full-opacity board numbers; backed summaries/actions |
| Setup, preferences | Solid form/control surfaces and backed standalone guidance |
| Six pack detail/owned screens | Backed descriptions/purchase copy and opaque actions |
| Shop, bundle, results | Dark base and opaque rows/panels |
| Rules/privacy | Opaque rule panels and backed paragraphs |
| Reports, age confirmation, reconnect | Backed supporting copy or opaque native/modal surface |

## Verification

`python3 scripts/check-text-contrast.py` checks 13 production palette pairs against 4.5:1. Protected supporting text is at least 9.26:1 on ink; the lowest checked pair is lilac on violet at 4.72:1. Board numbers are 4.86:1. These palette checks do not automatically establish contrast at every rendered pixel or test truncation.

Native run 35527839000 at ac7a2fa passed both contract tests and all six UI tests; the executed-test log confirms TEST SUCCEEDED. Reviewed all 54 exported captures on 21 September, including the 26 concepts, all twelve pack screens, rules/privacy/profile, eight-player layouts and accessibility XXXL. Art no longer crosses the protected copy; guest settings and away names remain readable. Large-text screens retain scrolling and visible primary actions. Artifacts: ignored build/visual-readability; review contact sheets: review/1.jpg through review/9.jpg. Real-device readability and VoiceOver review remain separate acceptance checks.
