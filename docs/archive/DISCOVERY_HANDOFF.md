# Complete discovery handoff — 9 September 2026

## Latest user instruction takes precedence

The user rejected the previous plan's assumption that this app would use the same infrastructure as Hvem mon?. Their instruction:

> I want you to do everything from scratch, so it is a native iOS app. That looks unbelievably good, as if a top-tier iOS app developer and UI designer would make it. There are a lot more questions you need to ask me, but right now I need you to create a new folder in the root and call it the name of this new app and everything it needs, so it knows exactly what we have talked about. Then I will open a new terminal and open a new session inside of that folder, and I will continue our conversation there.

This directory fulfills that handoff request. No implementation was requested as part of creating it. The parent directory is the user's home/project root, `/Users/nicklasandreasen`, rather than the filesystem `/` or the showcase website repository.

## User, portfolio, and motivation

- User: Nicklas Andreasen, Danish, developer brand Adrez. Conversation has been in English; game content is intended for Denmark.
- Existing published iOS games: **Vildsvar: Selskabsspil** and **Hvem mon? Guess your friends**. Both are free and advertise no in-app purchases.
- Vildsvar involves hidden differences, clues, and identifying an outsider. Hvem mon? involves recognizing the authors of anonymous personal answers.
- The user wants a new game with in-app purchases, an ambitious flagship level of polish, but extremely easy gameplay.
- Existing website: `/Users/nicklasandreasen/adrez.dev`. Other existing game projects are nearby, but they are context only and are NOT the architecture or codebase for this app.
- The user has just released Hvem mon?. Its website card was updated, committed as `2f4e248`, pushed, and verified live. That separate task is finished.
- macOS Command Line Tools were repaired during the earlier session. `xcrun --version`, `git --version`, and repository commands succeeded afterward; Git reported `2.39.5 (Apple Git-154)`. This does not establish that full Xcode/simulator/signing requirements are ready; inspect those if relevant later.

## Intended feeling and audience

- A Danish pre-party game that friends can enjoy for an evening around a table or while talking in Discord.
- The user explicitly frames it as a drinking game and enjoys betting/forfeit mechanics familiar from Danish drinking games. They mentioned wagering sips and drinking instead of doing a challenge during brainstorming.
- They want embarrassing revelations, catching a liar, friendly competition, and small factual mini-games.
- Very low cognitive load: short questions, large simple choices, minimal instructions. No lengthy text entry, invented stories, complicated roles, or mandatory performances.
- The app should remain easy to read and operate in a noisy pre-party setting. Do not optimize the mechanics for increasing intoxication; the exact optional drinking/forfeit layer is unresolved.
- It should feel like a competitive board game with progression and a finish, not an endless unrelated question deck.
- Everyone uses their own device. **No separate host display and no requirement to share a screen.** A host still exists for lobby configuration and starting the match.
- Discord is a social setting, not a request to build voice chat or a Discord integration.

## Explicitly agreed core round — preserve this

1. All players see the **same question** on their devices.
2. Each player privately chooses and locks their own answer.
3. **After answering**, they choose one other player they believe will answer correctly. The question is known before backing a player.
4. Other players' answers remain hidden. Backing choices also remain hidden until the reveal.
5. Once everyone has both answered and backed someone, reveal the correct answer, player answers, backing choices, and points together.
6. Award **1 point for your own correct answer + 1 point if the player you backed answered correctly**.
7. Everyone moves 0, 1, or 2 spaces on the shared board.

| Own answer | Backed player's answer | Points |
|---|---|---|
| Correct | Correct | 2 |
| Correct | Incorrect | 1 |
| Incorrect | Correct | 1 |
| Incorrect | Incorrect | 0 |

- No self-backing. Multiple players can back the same player.
- A backed player's own backing selection does not affect your result; no recursive scoring.
- Everyone participates every round. Earlier spectator-only duel structures were superseded by this idea.
- This is prediction scoring, not a settled token wallet or stake-loss system. Do not reintroduce separate betting currencies by default.
- User explicitly confirmed: "yes, let's do this exactly" and specified answering first, then choosing another player, then revealing once everyone has finished.

## Explicitly accepted race structure

- Race to a host-configured finish line.
- Offered and accepted: **10, 20, or 30 spaces**, plus custom distance; **20 default**.
- Complete the entire round's scoring/reveal before checking the finish.
- If multiple players cross in the same round, the furthest ahead wins. Equal furthest scores are joint winners.
- Host participates normally from their device.
- These distances are not promises about real-world session duration.
- Custom-distance bounds were NOT discussed with the user. The previous plan invented 5–100; revisit rather than treating that as settled.

## Mini-games and content decisions

User specifically requested examples such as:

- Higher/lower or over/under.
- Two films: which earned more at the box office?
- YouTube creators: who has more subscribers?
- Other quick, varied factual games, potentially fed by free APIs or data sources.
- Social questions involving embarrassing truths and lies.

The invariant is the common **answer → back someone → reveal → 0–2 points** loop. Variety should come from content and compatible mini-games, not making the group learn new rules constantly.

When asked about launch content, user selected:

1. **Curated mix:** free starter pack plus paid Denmark, Film & TV, and personal-question packs; use verified content with cleared rights.
2. **Guess the group** for social rounds: privately answer yes/no, then guess the group's total and back a friend; correct total guesses earn the usual points.

The social selection adds a private setup step before the normal answer/back sequence. Proposed behavior: reveal only the aggregate personal responses, not individual yes/no answers. Individual guesses and backing results can be public. Explain and confirm this privacy choice and its fit with the user's desire for embarrassing reveals.

Potential factual formats: higher/lower, before/after, true/false, over/under. Exact launch roster is still to settle.

The specific scoring threshold for group guesses, minimum group size, skipping personal questions, and handling missing responses have NOT been thoroughly discussed. The previous plan proposed exact matches, excluding skipped responses, and cancelling below three respondents; these are proposals, not user-confirmed rules.

YouTube/live-data content was deferred by the curated-mix choice, not rejected forever. A liar mini-game has not been designed or committed for v1. Do not force it in without resolving its information and scoring asymmetry.

## Monetization — required, not a later optional add-on

- User explicitly reiterated: "remember to implement the packs that you can buy."
- Direction agreed in conversation: **permanent themed content purchases**, with the host's selected purchased packs available to everyone in their room.
- Free content should support complete, replayable matches. Guests should not have to buy the same pack to join.
- Proposed launch themes: **Danmark**, **Film & TV**, and **Tæt på** (personal questions), plus a free starter mix. The theme choice is accepted; final names/copy/content are not.
- Native Apple in-app purchases and restore purchases are intended. Entitlements must be trustworthy; implementation/provider/account model remains open.
- Do not sell points, answers, competitive advantages, or in-game wagers.
- Subscriptions, ads, bundles, family sharing, pricing, offline ownership, refunds, host changes, and combining ownership across players still need discussion where relevant.
- Previous plan's **29 DKK per pack** is an unvalidated assistant pricing hypothesis, not a user-selected price.
- Previous plan's **100 questions per pack**, no ads, and no bundle for v1 were assistant defaults, not confirmed requirements.

## Native design and architecture requirement

- Build a **genuinely native iOS app from scratch**, with exceptional typography, composition, animation, haptics, responsiveness, and interaction craft.
- No reuse of Hvem mon?'s stack/infrastructure and no assumed Capacitor/web-wrapper solution.
- Do not conflate ambitious visual quality with complex game rules.
- Swift/SwiftUI, minimum iOS version, iPad support, orientation, visual direction, accessibility, board presentation, and motion style need exploration.
- Multiplayer still needs a separately chosen synchronization and backend approach. Native client does not mean backend-free.
- Browser guest participation was inserted by the prior assistant plan. **It is not confirmed under the new native-only direction.** Ask whether all players must have iPhones or whether Android/browser guests are needed.
- A separate repository is intended; no stack, project scaffolding, backend, signing setup, product identifiers, or paid resources has been created here.

## Research already performed — starting points, not blanket clearance

Existing listings:

- https://apps.apple.com/us/developer/nicklas-andreasen/id6807314845
- https://apps.apple.com/us/app/vildsvar-selskabsspil/id6807314843
- https://apps.apple.com/us/app/hvem-mon-guess-your-friends/id6809198474

Monetization precedents inspected:

- Wavelength lists content packs/bundles: https://apps.apple.com/us/app/wavelength/id1512834505
- Spaceteam lists a permanent upgrade: https://apps.apple.com/us/app/spaceteam/id570510529
- These demonstrate purchase models, not revenue projections or validated willingness to pay for this app.

Data sources:

- TMDB FAQ: https://developer.themoviedb.org/docs/faq
  - Free API access is for noncommercial purposes with attribution. Commercial data/image licensing requires contacting them. Do not assume a revenue-generating app can use the free developer terms.
- YouTube channel statistics: https://developers.google.com/youtube/v3/docs/channels
  - Subscriber counts are rounded to three significant figures; hidden counts are indicated. Exclude ambiguous comparisons. Full commercial usage, caching, refresh, and redistribution policies still require review before adoption.
- Suggested content approach: reviewed question sets from permitted sources, provenance per question, frozen factual answers for each round/match. Do not make a live question depend on an API responding during play.
- Images, posters, music clips, and logos require their own rights consideration; an accessible API is not blanket permission.

App Store constraint already raised with the user:

- https://developer.apple.com/app-store/review/guidelines/#physical-harm
- Guideline 1.4.3 prohibits encouraging excessive alcohol consumption or consumption by minors; 1.4.5 addresses physically harmful bets/challenges.
- Design an actual compatible experience; do not merely disguise mechanics in store copy. The user has not yet finalized the drinking layer. Keep the discussion concrete, brief, and connected to shipping the app.

Relevant skills previously read: `competitor-analysis` and `monetization-strategy` in `/Users/nicklasandreasen/.codex/skills`. Other likely helpful skills are available for native Swift, Apple design, and animation; read applicable instructions before use.

## Rejected or superseded brainstorming

- Elaborate company-crisis roleplay, courtroom performances, collective alibis, long confessions, and invented stories: too complicated for the user's desired pre-party experience.
- Solo casual puzzle direction: user chose social comedy instead.
- Scheduled duels every fifth round: user wanted more participation and variety.
- Spectator-only betting with a central/shared host screen: superseded by all-device, everyone-answers gameplay.
- Separate replenishing betting tokens: assistant suggestion, superseded by the simple 0/1/2 scoring idea.
- Fixed round count: user explicitly chose a finish-line race.
- Reusing Hvem mon?'s technical infrastructure: explicitly rejected in the latest instruction.

## Questions for continuing discovery

Do not ask this whole list at once. Start with high-impact choices and use the answers to guide subsequent exploration.

### Audience and platforms

- Native iPhone-only participation, or must Android/browser friends be able to join?
- Player count, minimum iOS version, iPad support, and Danish-only versus bilingual launch?
- Adults-only positioning and the precise role of optional drinking/forfeits?

### Visual and interaction direction

- What visual references match the user's top-tier quality bar: tactile tabletop, playful game-show, elegant social app, or another direction?
- Portrait layout, board shape, player identities/avatars, readability, sound, haptics, reduced motion?
- How should the synchronized reveal unfold, and who advances it? Auto progression versus ready/continue?
- Final app name; is “En til?” appealing or only a placeholder?

### Gameplay details

- Exact v1 mini-games; does every factual question have two choices?
- Whether answers can be revised before locking, and whether players can revise backing choices before the reveal?
- Timeouts, pauses, disconnects, leaving, late joins, host replacement, rematches, and AFK handling?
- Detailed group-question scoring, privacy, skips, and response-count display?
- Preventing repetitive backing of the strongest player: first playtest the simple rule rather than adding restrictions without evidence.
- Do match lengths need guidance after real playtests? Custom finish bounds?
- Is any future liar mode required for launch, or is group guessing sufficient initially?

### Packs and business

- Final pack names, content quantities, tone limits, initial pricing, bundles, previews, and purchase moments?
- Only host-owned packs, or allow anyone's purchased pack to be contributed to a room?
- What settings/custom prompts should players be able to create, and are they private to their room?
- Will original content be authored manually, assisted by tools then reviewed, or licensed? Who approves sensitive questions and factual accuracy?

### Engineering and release

- New native architecture and backend options based on requirements, budget, and operational preferences; do not default to the old app.
- Authentication/accountless joining and purchase identity, entitlement validation, persistence, privacy, analytics, and moderation needs?
- Separate git repository, identifiers, signing/developer account, testing devices, TestFlight path, and release responsibilities?
- No deployment or App Store approval inherited from the unrelated website task.

## State at handoff

Only these documentation files exist. No implementation, external resources, dependencies, or credentials were created. The correct next step is to continue the discovery conversation, not execute the previous assistant plan.
