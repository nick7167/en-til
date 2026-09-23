# Gameplay and UX review — 23 September 2026

The tested multiplayer loop completed without a detected scoring, progression or recovery failure. The strongest next improvements are clearer readiness, a more continuous result-to-board transition, and social feedback at the moment of the reveal. Mini-games are a promising experiment after those changes, not a demonstrated requirement.

Question quantity is excluded from this review at the owner's request. No gameplay rules or app UI were changed during this review.

## Recording and method

- [Complete app session, 2:36.665](../build/gameplay-ux-review/en-til-complete-session.mp4).
- [Original recording, 6:56.665](../build/gameplay-ux-review/gameplay-session.mp4), including simulator/build preparation.
- [Passing native run 35806878909](https://github.com/nick7167/en-til/actions/runs/35806878909), commit `4ff514b`. Its `gameplay-session` artifact retains the original recording for seven days; local copies remain in ignored `build/gameplay-ux-review`.

The shorter recording removes only the first 260 seconds of setup, preserving launch, the entire match, deliberate app termination/reopening, rematch, leave and return. It runs at original speed. It is a simulator recording without audio, not a recording of the owner's phone.

Reviewed the complete recording through three-second frame samples, the app session at one-second intervals, and the first board movement/reaction at 0.1-second intervals. Cross-checked with XCTest logs and the responsible Swift/backend code. This supports layout and sequence findings, not device frame-rate, sound or haptic judgments.

Used the installed [Emil Design Engineering skill](/Users/nicklasandreasen/.agents/skills/emil-design-eng/SKILL.md): immediate feedback, purposeful motion, continuity, accessible alternatives and restraint in frequently repeated interactions. Applied its principles to SwiftUI; web-specific CSS recommendations are not app requirements.

## What passed

| Check | Evidence / scope |
| --- | --- |
| Native complete match | `testLiveMatchReopenAndRematch` passed in 198.826 seconds; executed log contains `TEST SUCCEEDED`. Native guest plus two scripted API participants against a real local Worker. |
| Join and readiness | Code entry, name/character confirmation, lobby, ready state and start. Host creation/settings/start are exercised through the API, not by tapping the host UI in this recording. |
| Factual rounds | Answer lock, backing another player, result disclosure, +2 and board movement. |
| Personal round | Private response, count guess, no backing step, all tied closest guesses receive +1. |
| Match boundaries | Five-point finish, three joint winners, rematch in the same room, deliberate leave and restoration of the same active seat. |
| Reactions and recovery | Emoji above Freja; terminate/reopen restores the board and scores. |
| Engine/RPC | `pnpm check`: TypeScript and all 32 tests pass. Includes independent scoring combinations, stale/duplicate commands, deadline boundaries, privacy, overshoot, host transfer, late/away players and missed turns. |
| Real transport | HTTP eight-player admission/auth/round checks and authenticated WebSocket reconnect checks pass. |
| Persistence | Two actual Worker restarts preserve authentication, room, round and results without duplicate scoring. |
| Bot/rate/load checks | Bot complete-match self-test and rate-limit rejection pass. Local load: 100 rooms, 800 sockets, 4,100 HTTP requests in 51.51 seconds; p95 160.65 ms, p99 218.48 ms. This is local Miniflare, not production capacity. |

The full eight-test native suite had already passed for the same gameplay implementation in run 35782119718; this new run focused on the live session and recording. Backend CI 35806867116 also passed. The only code change for this task adds optional simulator recording to the native workflow.

The recorded match is intentionally short, untimed and uses correct scripted answers. It does not demonstrate a natural twenty-point match, varied human strategies, a trailing player's experience or sustained enjoyment. Timers and unequal scoring are covered by engine tests, not visibly demonstrated here. Purchases, physical VoiceOver, small-device/iOS 18 behavior, sound and haptics remain outside this recording's evidence.

## Session guide

Times refer to the shorter recording; add 4:20 for the original.

| Approximate time | Event |
| --- | --- |
| 0:00–0:06 | White launch presentation, then home |
| 0:17–0:35 | Join, keyboard, character selection and lobby |
| 0:36–1:13 | Factual answer, backing, reveal and board |
| 1:14–1:18 | Reaction above Freja |
| 1:19–1:28 | Deliberate termination/reopen and restored board |
| 1:31–1:35 | Ready state and countdown |
| 1:36–1:55 | Private answer, personal guess, +1 reveal and board |
| 2:02–2:20 | Final factual round and shared victory |
| 2:21–2:34 | Rematch, leave, return and active-seat restoration |

The long first backing selection includes XCTest synchronization delays. Do not interpret it as measured network latency or a mandatory game delay. The first keyboard tutorial belongs to iOS. The host immediately rematches in the script, so the brief finale is not an automatic dismissal by the app.

## Prioritized UX recommendations

These are proposed changes, not implemented fixes. P1 means first polish pass; none is a demonstrated gameplay blocker.

| Priority / evidence | Before | After | Why |
| --- | --- | --- | --- |
| P1 — 1:31–1:33, 1:57–1:58; `RoomView.board` | After readying, the main feedback is “Vent, jeg er ikke klar”; no visible ready count or indication of who remains. | Show “Du er klar · 2/3 klar” and waiting players, with a quieter undo-ready action. Retain explicit readiness. | Makes the current state clear and avoids making the primary button sound as if the player is currently unready. |
| P1 — 1:05–1:13, 1:47–1:55; `engine.advance`, `RoomView.reveal/board` | Reveal → rows → movement-only board → regular board. The board shifts when controls appear. Rules impose 7.8 seconds for reveal plus a later 3-second countdown, excluding user readiness. | Keep one stable board composition as movement settles and controls become available. Test removing the extra movement-only hold and a shorter repeat-round countdown. Keep results available through “Se alle svar”. | Reduces repeated stops without rushing reading or silently starting before everyone is ready. Prototype timings rather than treating faster as automatically better. |
| P1 — 0:00–0:05, 1:20–1:25; empty `UILaunchScreen` | A bright white launch screen interrupts the dark app; reopening briefly shows home before restoring the board. | Match the native launch background to the app, then show an explicit restoring state until the saved room is resolved. | Preserves continuity and explains recovery. The white presentation is observed; its duration on physical hardware still needs measurement. |
| P2 — 1:05, 1:47, 2:11; `RoomView.reveal` | Before result rows, the same large red character appears regardless of who succeeded. | Keep focus on the answer/count, or use a neutral reveal treatment. Use player-specific celebration only when warranted by results. | The placeholder can be mistaken for a winner indicator. This is a clarity risk inferred from the visible design, not observed human confusion. |
| P2 — 1:14–1:18; reactions are currently board-only in the UI | Reactions work well, but only after the result sequence. | Test allowing reactions on revealed results too, anchored to the sender's result avatar. Preserve rate limits and Reduce Motion. | Lets friends respond when the surprising answer appears. Keep the current character-origin presentation. |
| P2 — 0:40 and 2:07; `RoomView.question` | Backing shows the question but no reminder of the player's locked answer. | Add a compact “Dit svar: Mars” confirmation above the backing choice. | Confirms the previous action and reduces memory work when the screen changes. |
| P2 — 1:28 onward; `WindingBoard` | The board centers on the local player; a leader far ahead can be out of view in longer matches. | Add a small rank/gap summary using existing scores, e.g. “2 point efter Freja”. | Gives trailing players a clear immediate target. This is a longer-match design hypothesis, not demonstrated by the tied match. |
| Experiment — setup already offers 10/20/30 points | Match length is expressed only in points. | Test descriptive labels such as “Kort · 10”, “Standard · 20”, “Lang · 30”, and offer the short option prominently for first play. | Gives groups control over commitment. Do not promise minutes until normal human sessions establish actual durations. |

Keep the strong parts: character identity, visible selection/lock states, optional private-answer skip, personal rounds without backing, +1 for tied closest guesses, and restoring a seat without repeating setup. Preserve the opportunity to talk between rounds; not all waiting is wasted time in a party game.

## More variety and mini-games

Start with one optional prototype, not a collection of modes. It should replace an ordinary round, take one short instruction, use simultaneous input and award at most one point. Avoid speed-based scoring, compulsory drinking, humiliating challenges and revealing private responses.

| Candidate | Concrete version to test | Benefit / tradeoff |
| --- | --- | --- |
| **First choice: “Sæt i rækkefølge”** | Three items; everyone arranges them in the requested order. One submission, one reveal, +1 for the correct order; ties allowed. Provide tap-to-move controls as well as drag for accessibility. | A different interaction and shared comparison moment without a separate lobby or turn-taking. Needs clear ordering criteria and accessible controls. Try one round after several ordinary rounds, not on every turn. |
| Later option: cooperative round | A short round announces a shared target before answers; each player who answers correctly earns their normal point, with a shared celebration if the announced target is met. | Changes the social mood without rewriting the race or punishing everyone for one player's mistake. A joint celebration may be enough; do not add currencies or bonus systems prematurely. |
| Later option: optional lightning set | Three simultaneous true/false choices, followed by one combined reveal. Score accuracy, not milliseconds; allow the timer to be disabled. | Changes rhythm more strongly, but increases reading/time pressure and can feel like more quiz work. Test after the ordering prototype. |

I would not begin with power-ups, stealing points, elaborate comeback multipliers, more compulsory confirmations or an additional reward currency. Those add rules and fairness questions before we know whether variety or pacing is the real problem.

## Suggested next experiment

First address readiness, board continuity and launch/recovery presentation. Compare the current and revised flow with the same scripted checks and recording. Then run short human sessions with three and six players, using the existing ten-point setting: one baseline game and one with a single ordering round. Alternate which version goes first between groups.

Observe whether people know who is holding up progression, can explain their points, talk during the reveal, and choose to rematch. Ask which moment dragged and whether they want the mini-game again. Record time spent waiting after everyone finishes, rather than penalizing voluntary conversation. Do not infer human enjoyment or boredom from bot success.


## Four approved polish improvements — 23 September 2026

Implemented at `d75ae27`: board readiness counts and waiting names with undo; continuous movement/board composition (movement at 4.8s, board ready at 6s, then a 2s countdown after everyone is ready); reactions on revealed result avatars; dark native launch color and explicit saved-seat restoration. Points remain visible from 1.8s. Personal scoring remains +1 for all closest guesses, without backing. No mini-games were added.

Full native run [35871203213](https://github.com/nick7167/en-til/actions/runs/35871203213) passed three contract tests and six UI tests, including a real three-player match, readiness undo, reveal reactions, reopening, joint finale, rematch and leave/return. The executed log confirms `TEST SUCCEEDED`. Reviewed full-resolution result/reaction/readiness/movement and accessibility XXXL captures under ignored `build/polish-review`. Waiting names, ready count, undo and reaction controls are visible; large text remains scrollable with the primary action accessible.

Local backend checks pass 34 tests, HTTP/WebSocket integration, two process restarts and bot self-test. Backend CI 35871197178 passed. Beta version `0a26aca1-b019-4c4d-97f7-572194067f8f` is deployed; remote bots verified factual/personal scoring, reveal reactions, reveal duration, heartbeat and clean departure.

This is simulator and automated-client evidence. Physical-device pacing, audio/haptics, VoiceOver and human enjoyment still need device/group feedback.


Recording review completed: inspected the complete live session at one-second intervals and movement/reopening at 0.1-second intervals. Session-only silent video: ignored `build/polish-review/en-til-polish-session.mp4` (source starts at 774s; original full-suite recording retained in `build/polish-review/video/gameplay-session.mp4`). It shows joining, four rounds (personal/factual), character-origin reactions, readiness undo/countdown, termination/reopening, shared victory, rematch, leave and return. Movement retains the board/control geometry; readiness enables after movement. Reopening stays dark, displays saved-seat restoration and returns to the board without an app-home flash. A brief reconnect overlay remains while the socket reconnects. This frame review does not measure real-device frame rate or startup speed; the simulator recording has no audio.

Build **1.0 (5)** uploaded and Apple processing completed. The configured `Internal Testing` group was not found; see [hosted builds](HOSTED_BUILDS.md) for delivery evidence and the remaining group-assignment limitation.
