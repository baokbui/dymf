# Milestone 20 retention

**Steps 0–6 implemented. Step 7 release verification is in progress.** See `ROADMAP.md` for the remaining checks.

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

The Menu's **Quests** entry opens **Daily Quests** / **Weekly Quests** /
**Campaign** tabs. Titles and tabs stay fixed; only the objective list scrolls.
All three tracks and Achievements put completed, unclaimed rewards first.
A compact right-side tracker between Damage and Start Day also shows both
tracks as text-only progress. A single clickable heading switches between Daily Quests and Weekly Quests.
Completed objectives animate away from the tracker; rewards remain claimable
from the full Menu quest view, and its badge includes completion bonuses.
When no tracker rows remain, it shows “No quests for today” or
“No quests for the week” for the selected track.
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
  Campaign clears credit clear objectives. Daily Challenge does not credit quests or achievements.
- Progress updates are server events, never client submissions. Claims require
  the matching active period and objective completion. Each reward pays once.
  Daily and weekly progress/claim flags are independent.

Weekly quests replace recurring weekly login rewards; there is no weekly login
payout. Maximum quest income is 6/12/18 daily plus 13/26/39 weekly brains.
The weekly component averages about 1.86/3.71/5.57 brains per day if fully completed.
There is no balance cap. Ten permanent achievements add 75 brains once. Campaign quests add up to 95 brains across the 10 milestones.
Forest Rush pays 8 or 12 brains per UTC day based on the highest unlocked day. The free spin adds an expected 1.7 base brains per eligible day before reward-band scaling.

## Campaign quests and achievements

**Quests → Campaign** tracks the highest campaign day unlocked, including for
existing saves. Days 5 through 50, in five-day increments, each unlock a
one-time claim worth 5 to 14 brains. The rewards use the permanent claim
ledger and do not expire. Replaying or selecting a day cannot advance the
highest unlocked day or repeat a claim.

Achievements also track first Legendary and God evolutions, 100 and 500
monster defeats, and 100 Brainrot placements. Existing saved statistics and
verified owned evolution tiers count toward those milestones. Daily Challenge
play is excluded from those statistics.

## Daily Challenge

**Forest Rush** unlocks at Day 10. Enter from the Day panel during campaign
Preparation after your plot is ready. It uses a temporary empty lawn on the
owned plot, 350 coins, three hearts, Day 10 enemy scaling, and no magnet.
The normal equipped roster and upgrades apply. Challenge planting, coin
pickups and kills do not advance campaign statistics, XP, quests or
achievements. There is no leftover-coin conversion.

Clear or defeat restores the campaign lawn, purse, hearts, and pending Hidden
Day. Leaving drops the temporary run. Rejoin restores the regular campaign
checkpoint. The first clear pays automatically for the server UTC date at
completion. Retries are free. Save schema v12 writes the UTC receipt and
brains together. Reset Progress preserves the receipt so it cannot reopen
the same payout. A failed or expired save never reports reward success.
Analytics records attempts, retries, clears, losses, and reward outcomes.

## Free daily spin

The **Daily Spinner** HUD button unlocks after clearing Day 2 and resets at 00:00 UTC.
The base pool awards 1 brain at 60%, 2 brains at 30%, or 5 brains at 10%.
The normal highest-unlocked-day multiplier scales amounts. The panel shows
current payouts and odds. The server chooses the result and commits the receipt
and brains together before the client reveal. The client shows a rotating wheel
with proportional 60/30/10 sectors and a fixed pointer. It makes five full turns
over four seconds, slowing to the saved reward's sector. Rejoining shows the committed
result for that date. Reset Progress preserves the daily receipt.

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

Reset Progress preserves this track's claim history, including partial progress,
so completed rewards never reopen. Only Speed/Magnet levels actually awarded
by the track carry over (normally Speed 2 and Magnet 2 including its base level).
Purchased levels reset. Unused tickets survive; redeemed tickets are not refunded.
Brains reset without replaying any first-time brain payouts. The optional
`login.upgradeRewards` map records actual granted levels, excluding max-level
brain fallbacks. Older profiles infer carryover once from claimed upgrade steps,
capped by currently owned levels; their historical fallback payouts cannot be
distinguished because the previous schema did not record their source.

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

Current save schema **16**, retention internal version **4**, stores daily and weekly
quests, first-time rewards, permanent achievements and Campaign claims, tickets,
Daily Challenge receipts, and Daily Spin outcomes.
Only SaveService communicates with DataStore via SessionStore owner/revision/
operation-id guards and a session lease (180 seconds; autosave every 60 seconds).
Unavailable loads never become writable defaults; uncertain writes fail closed.

`claimRetentionReward` accepts Quest, WeeklyQuest, Login, Achievement, and Spin
from validated client intents. Campaign quests use the Achievement claim kind.
The server uses internal Challenge and Ticket kinds for encounter clears and
shop redemption. Each claim and its reward commit in one guarded record. A free upgrade/fallback, ticket grant or ticket
spend cannot be saved separately from its associated claim/unlock.

Store purchases return a saving/busy error while a player save transaction is
running, preventing a paid upgrade from racing a free upgrade. Queued save/leave
snapshots merge committed reward deltas and flags while preserving unrelated
progress. Daily claims revalidate their date in the write callback; weekly claims
revalidate their week and can cross ordinary midnight. Achievements/ticket spends
have no calendar expiry. Reconnect never replays a completed grant. Reset Progress
clears quest/achievement claims and unlocks while preserving first-time claim
history, first-time upgrade levels, unused tickets, and Daily Challenge/Daily
Spin receipts. Other upgrade levels reset.

## Achievements and goals

The original five achievements award 28 brains. Legendary and God evolutions,
100 and 500 monster defeats, and 100 placements add another 47. All use fixed
rewards. Ownership, evolution, and statistics catch-up use verified profile fields. Boss/perfect
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
`weeklyResetAt`, `login`, `brainrotTickets`, achievements, campaign milestones, and nextGoal. Claim
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

Step 7 isolated Studio verification passes 47 achievement and milestone
assertions, 45 first-time/weekly/ticket assertions, 32 quest/storage assertions,
58 sizing/layout/scroll assertions, 209 Menu checks, and 10 shovel checks.
The SaveService, RetentionService, and Daily Challenge integration fixtures
also pass. Coverage includes startup-order hydration, reset preserving the two
daily receipts, malformed claim arguments, spin spam, same-day repeats,
simultaneous writer requests, and reconnect after a committed outcome.
The configured economy review is in ECONOMY.md.

Release checks still require a full battle on a populated plot, four concurrent
players, real-device touch and desktop spinner input, real DataStore fault and
restart verification, and analytics ingestion in a published test environment.
Review D1/D7/D30 cohorts after enough live data accumulates.
