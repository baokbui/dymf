# Milestone 20 retention

**Steps 0–4 implemented, with first-time mixed rewards and weekly quests.**
Challenges and spinner remain planned. Follow `ROADMAP.md` one step at a time.

## Authority and modules

`RetentionConfig` owns immutable catalogs and reward bands. `RetentionTime`
provides UTC day keys and Monday-based week keys. `DailyQuests` shares pure
assignment, sanitation, event, and claim logic between daily and weekly tracks.
`LoginRewards` handles the finite first-time track; it no longer has a weekly
login cycle. `Achievements` and `NextGoal` keep permanent milestone semantics.
`RewardGrant` changes only SaveService-owned transaction snapshots, not live state.
`RetentionService` owns validated intent, server event credit, coalesced pushes,
reset scheduling, profile catch-up, and protected analytics.
Only `SaveService` / `SessionStore` access DataStore. ProgressService owns live
balances, upgrades and unlocks. Clients do not choose rewards, dates or progress.

## Daily and weekly quests

The Menu's **Quests** tile opens **Daily Quests** / **Weekly Quests** tabs.
A compact right-side tracker between Damage and Start Day also shows both
tracks as text-only progress. A single clickable heading switches between Daily Quests and Weekly Quests.
Completed objectives animate away from the tracker; rewards remain claimable
from the full Menu quest view, and its badge includes completion bonuses.
Both contain three objectives and an all-three completion bonus, manually claimed.
Daily quests reset at 00:00 UTC; weekly quests reset Monday at 00:00 UTC.
A weekly key is that Monday's UTC day key. Replay clears count as campaign clears.

- Daily: collect 150 coins (1 base brain), defeat 15 monsters (1), clear one
  numbered day (2), all-three bonus (2): **6 base brains per day**.
- Weekly: collect 1,500 coins (3), defeat 150 monsters (3), clear seven numbered
  days (4), all-three bonus (3): **13 base brains per week**.
- Highest unlocked day bands: Days 1–9 = 1×, 10–29 = 2×, 30–50 = 3×.
  The selected/replayed day cannot change the band. Targets and exact rewards
  are snapshotted on assignment and cannot reroll by reconnecting.
- Real Campaign/Hidden pickup and kill credit survives defeat. Only numbered
  Campaign clears credit clear objectives. Challenge is excluded until designed.
- Progress updates are server events, never client submissions. Claims require
  the matching active period and objective completion. Each reward pays once.
  Daily and weekly progress/claim flags are independent.

Weekly quests replace recurring weekly login rewards; there is no weekly login
payout. Maximum quest income is 6/12/18 daily plus 13/26/39 weekly brains.
The weekly component averages about 1.86/3.71/5.57 brains per day if fully completed.
There is no balance cap. Five permanent achievements add 28 brains once.
Challenge (base 4) and spinner (base expected 1.7) are planned, not active income.

## First-time rewards

**First-time Rewards** is a standalone temporary HUD entry/window and a finite seven-step track, claimed once per distinct
server UTC date. These are real dates, not campaign days. Missing dates does not
reset or skip steps. The panel opens manually; it never interrupts a battle.

1. 2 base brains.
2. One Speed upgrade level.
3. 4 base brains.
4. One Magnet upgrade level.
5. 6 base brains.
6. One Speed upgrade level.
7. One free Brainrot-store ticket.

Brain rewards use the offer's progression band. An already-maxed upgrade pays
10 brains instead; no upgrade can exceed its catalog max. Upgrade grants are
permanent profile upgrades, not match bonuses. There are no match coins or XP
in this catalog. After claim seven, the track stays completed permanently and
has no reset countdown or next weekly track. First-time cards use centered icons and explicit captions such as `+4 brains`;
claimed cards use gray fills and retain their reward beneath a red Claimed stamp.

Existing welcome counts and last-claim dates are preserved. Legacy weekly-login
state is discarded, while previously earned balances/upgrades remain intact.
A legacy profile that completed all seven brain-only welcome rewards migrates
to six completed first-time steps, permitting a single final ticket catch-up on
a later eligible date. A migration marker prevents repeated catch-up grants.
Unclaimed legacy Welcome offers retain their date; the new step's reward kind
comes from the authoritative catalog, not old weekly data.

## Free Brainrot tickets

`retention.brainrotTickets` is a nonnegative saved count. At the owner's physical
Brainrot shop, an unowned catalog unit offers **Use ticket (N left)** in addition
to the normal paid button. A ticket unlocks one playable store-catalog Brainrot
without charging brains. It cannot buy starter/campaign Brainrots, upgrades,
already-owned units or a unit absent from the store catalog. Tickets have no
expiry and remain saved if all currently sold units are owned.

`BuyStoreItem` accepts optional `useTicket = true`. Server ownership/distance
checks apply to ticket use just as to paid purchases. SaveService validates
again and atomically saves the unlock/loadout/intro fields with the consumed
ticket before reporting success. Duplicate requests cannot spend it twice.
No client chooses a price or sets the ticket count.

## Durability and concurrency

Save schema **11**, retention internal version **4**, stores daily and weekly
assignments/progress/claims, finite login state, permanent achievements, tickets.
Only SaveService communicates with DataStore via SessionStore owner/revision/
operation-id guards and a session lease (180 seconds; autosave every 60 seconds).
Unavailable loads never become writable defaults; uncertain writes fail closed.

`claimRetentionReward` supports Quest, WeeklyQuest, Login, Achievement and the
internal Ticket purchase path. It commits the claim plus reward in one guarded
record. Remotes expose only the first four claim kinds; Ticket is reached through
validated shop purchase intent. A free upgrade/fallback, ticket grant or ticket
spend cannot be saved separately from its associated claim/unlock.

Store purchases return a saving/busy error while a player save transaction is
running, preventing a paid upgrade from racing a free upgrade. Queued save/leave
snapshots merge committed reward deltas and flags while preserving unrelated
progress. Daily claims revalidate their date in the write callback; weekly claims
revalidate their week and can cross ordinary midnight. Achievements/ticket spends
have no calendar expiry. Reconnect never replays a completed grant. Reset Progress
clears retention, ticket balances, unlocks and upgrades with the rest of the save.

## Achievements and goals

Permanent milestones: FirstBoss (5), FirstEpic (5), FirstPerfectDefense (3),
OwnFiveBrainrots (5), OwnTenBrainrots (10), fixed brains independent of bands.
Owned types and claimed Epic catch-up use verified profile fields. Boss/perfect
history needs new server events, never intro flags or fabricated old statistics.
A perfect defense is a numbered-day clear with zero breaches during that attempt;
ending at full hearts alone is insufficient. Attempt breach flags are not saved.

NextGoal selects one owned/equipped evolution or nearby free campaign unlock,
then a level gate, then campaign/replay guidance. It cannot purchase or start days.
Goal view requests validate the current server ID and use bounded analytics.

## UI and networking

Quests and Achievements are sections of the shared Menu. First-time Rewards
has its own gift HUD button above Menu, remaining available between claims and
hiding after server-confirmed completion of all seven rewards. It is not a
Menu tile; completed profiles do not show the button on rejoin.
Quest tabs have independent progress and period countdowns. Achievements is
permanent and shows no reset timer. The backdrop is transparent. Reward amounts
show a number followed by brain texture `12691330734`, with no '+' prefix.
First-time cards instead show the reward icon by itself, with a `+N reward`
caption below. Speed/Magnet use HUD textures; the ticket uses a UI illustration.
The intro/next-step copy is removed, and the claim button hides after today's
claim. Collected cards keep their icon/amount under a red Claimed stamp.
The default footer is empty; only claim feedback appears there.

`RequestState.retention` / `RetentionUpdated` supply daily data plus `weekly`,
`weeklyResetAt`, `login`, `brainrotTickets`, achievements and nextGoal. Claim
intent contains `kind`, period `dayKey`, and bounded `id`. Server validates type,
finite integer period, catalog, completion, date and request throttle (0.5s).
Pushes coalesce at 0.35s. `RetentionClaimResult.reward` describes non-brain grants;
`brainsGranted` remains the exact brains delta. Store success reports cost zero
for ticket redemptions, reusing purchase audio without a brains deduction popup.

## Verification and remaining QA

Isolated tests use mocked players, remotes and in-memory storage, never live data.
They cover finite claims and legacy catch-up, typed rewards, Monday rollover,
quest isolation, maxed upgrade fallback, ticket eligibility/consumption,
SaveService migration, concurrent save/leave merges, durable duplicate prevention,
server event filters, achievements and Menu state. Rojo build and script compile
checks complement those fixtures. Full real-device visual QA, four-player battle
isolation/performance, cloud fault tests and live analytics remain Step 7 work.
Studio DevConfig cheats are unchanged; do not test economy balance on boosted
profiles or claim a retention lift before real D1/D7/D30 cohorts exist.

Latest isolated verification: 45 first-time/weekly/ticket pure assertions,
32 quest/storage checks, 32 achievement checks, 207 Menu/standalone reward checks, and full
SaveService/RetentionService in-memory integration fixtures pass. These are
not real cloud-storage or four-player gameplay tests.
