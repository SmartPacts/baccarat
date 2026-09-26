# Baccarat — how it works, and everything that can go wrong

Every number in this document that states a rule of the contract is checked against it by
`.github/scripts/check-player-terms.sh`; if the contract changes and this page does not, the gate
fails. The per-shoe figures, drand's cadence and the growth estimate are measurements, said so
where they appear. The behaviours described here are pinned by named tests on the contract's own page, which
marks the few not yet pinned.

---

## The game

Punto Banco baccarat, dealt from **8 decks** — 416 cards. Two hands are dealt, Player and
Banker, and you bet on which will win, or on a tie. The rules of the deal are the official
Punto Banco tableau: no decision is ever made by a person, and the contract's tests prove every
cell of that tableau.

| bet | pays | house edge | your return |
|---|---|---|---|
| Player | 1 to 1 | **1.2351%** | 98.765% |
| Banker | 0.95 to 1 (a 5% commission on the win, the launch setting) | **1.0579%** (at 5%) | 98.942% |
| Tie | 8 to 1 | **14.3596%** | 85.640% |

On a tie, a Player or Banker bet is **returned** — not lost, not paid. The edges are computed
from the exact eight-deck odds (Player wins 44.6247%, Banker 45.8597%, tie 9.5156% of coups)
and written into the contract as that arithmetic, not as typed numbers.

**The Banker commission is a setting the operator controls.** It launched at **5%**, and the
contract holds it to a range: never below **2.6932%** — the point at which the Banker bet would
pay out more than the pot expects to win — and never above 100%. A round that has opened keeps
the commission it opened with; a change reaches only rounds that have not started yet, and
every change is a public transaction. **The commission you accept is part of the board you
sign.** If the round's commission is higher than the one your board accepts — because the
setting changed between the page and the block — your bet is refused, never paid at the worse
rate. The Player and Tie payouts are constants no setting can move.

## A round

1. **You place a board** — any mix of Player, Banker and Tie, **0.01 KDA** minimum in total.
   This is the only thing you sign. One board per round: place everything in that one
   transaction. The minimum, the commission, the closing time and the share of the pot the
   round may risk are fixed when the round opens and nothing changes them while it is open;
   the table limit itself is measured against the smaller of the pot at open and the pot now,
   so it can shrink while the pot stands below where it was at the open, recover as the pot does,
   and never exceed the limit the round opened with.
2. **Betting closes 120 seconds** after the round opens. The window is a dial: never under 30
   seconds, never over an hour, and a change binds the next round.
3. **The cards come from drand** — a random number produced every 3 seconds by a group of
   independent organisations, outside Kadena entirely. The round is locked to a specific drand
   number **120 seconds after betting closes**, so it does not exist while you can still bet.
   The wait is a setting the operator controls, and the contract holds it to a range: never
   below **60 seconds**, never above an hour. That floor is the lowest the setting can go, not a
   value that would be safe to run at.
4. **Anyone submits it.** The contract checks the cryptographic proof itself, so a fake number
   is rejected, and it deals the coup from that number. drand numbers never expire, so a round
   settles correctly whether that happens in a minute or a month.
5. **If you won, you claim.** If you lost, you do nothing.

**Why not a Kadena block?** Because whoever produces that block would see the cards first and
could throw the block away if they did not like them. drand is produced off Kadena, so no
miner touches it.

## The shoe

The shoe is a **pool**, not a stack. The contract keeps a count of every card still in it.
When a coup is dealt, each card is picked from what remains by the coup's drand number, so the
next card does not exist until that number does — nobody can simulate a coup before its beacon
is published, and anyone can recompute it afterwards. Cards leave the pool as they are dealt.
When **52 cards or fewer** remain the pool is refilled before the next coup; that cut is a
setting the operator controls, between **14** cards and a full shoe, and a round keeps the cut
it opened under.

Coups are dealt **in round order**: round 2 cannot be dealt before round 1. So the shoe you see
is the shoe as of the last coup dealt, and a coup still waiting for its number will remove four
to six unknown cards before yours.

**What a public shoe means for you.** The cards left in the pool are public, so anyone —
including you — can compute the exact odds of the next coup from them. The page shows them.
Very rarely, a bet is better than even for the player for one coup; measured over 2,000 shoes,
a perfect card counter betting the table's cap at every such moment would gain about **0.002
KDA per shoe** at the launch cut of one deck, about 0.65 at the floor of 14 cards, and nothing at
all when the cut is two decks or more. That is the honest size of it, and it is the same for
every player.

## Table limits

The portion of the pot one coup may risk is a setting the operator controls, and today it is
**2%** of the house's spare capital. The operator can raise or lower that portion at any time,
can raise or lower the table minimum at any time, can move the commission and the cut card
within their ranges, can lengthen or shorten the betting window and the wait before the drand
number is locked in, and can move the pot's target, the level below which the fee ramps down
— **including after the contract is frozen**, because all of these are day-to-day settings and
not part of what freezing locks. Every such change is a public transaction on the chain, and
none of them can change what a round already taking bets froze: its portion of the pot, its minimum, its
commission, its cut, its window and its beacon. The one figure read live is the pot's target: a
change to it moves the fee accrued by later boards in that round, and with it the room the round
has left under its limit.

The contract's own bound on the portion is arithmetic and nothing else: it refuses any portion
above **100%** of the pot's spare capital, because a round cannot risk more than the pot has
spare. There is no upper bound on the minimum bet, and the table minimum can never be set below
**0.001 KDA**.

The limit applies to the **whole round**, not per player, and it uses whichever is smaller: the
pot when the round opened, or the pot now. Consequence worth understanding: **a round can fill
up.** If other players have already taken the round's capacity, your bet is refused and you wait
for the next one.

**What the pot is sized to keep.** A single coup may accept a Player or Banker bet up to the
maximum the page shows (the round's cap divided by what a win pays: about half of it on Player, a
little over half on Banker, about a ninth on Tie); the maximum the pot is sized to keep through a year of play is **one 250th** of
its spare capital, and the page shows both numbers. What such a bet takes comes out of the pot,
never out of another player's stake: the pot reserves your board's worst case before it accepts
it, whoever else is at the table.

**The pot can never fail to pay.** Before accepting any board the contract reserves the exact
worst case across the three outcomes. It can refuse a bet; it cannot run short on one it took.

## What you should know before you play

**You do not need any KDA to be paid.** The house runs a helper that sends every winner's
collection for them — and every refund — usually within minutes of the result. You sign nothing
and you need hold nothing: a collection always pays the account that placed the board, never
whoever sent the transaction. You can also collect yourself at any time, and so can anyone else
on your behalf. If the helper were ever down, nothing is lost — only delayed.

**Unclaimed winnings never expire.** They stay owed to you indefinitely. Nothing sweeps them to
the house.

**The fee never comes out of your stake.** It is paid by the pot, out of the house's own edge,
to the SPT treasury: at each bet's exact edge when the pot is at its target, less while the pot
is still filling. Your return is the table above whatever the fee does.

---

## 🔴 The honest limits

These are real. They are listed because they are true, not because they are comfortable.

**1. Until the contract is frozen, the operator's key controls the pot — and the rules.** The
same key that can upgrade the contract can move the pot's entire balance anywhere, and can
replace the contract's code, including how a round that is still waiting for its cards is
decided. Both are measured, not theoretical. Nothing can reach money you have already won and
claimed, but while the contract is upgradeable **the bankroll is custody, not escrow, and every
rule on this page holds only as long as the key leaves the code alone.** Freezing the contract
ends this, and nothing else about the game changes when it does.

**2. If drand is ever retired, rounds refund after 90 days.** Nobody can prove on-chain that a
number is gone for good rather than simply un-fetched, so the contract waits. One cheap,
public call from anyone shows the contract a newer beacon, and a round locked at or below the
newest beacon seen can then never be refunded: the refund exists only while the contract has seen no
beacon at or after the round's own, and a beacon published but never submitted counts as unseen. **Two consequences:** if
truly nobody acts for 90 days, a player who lost can take their stake back; and because a refund
applies to a whole round, it would also return a **winner** their stake instead of their
winnings. **If you win, claim it.** You can do that yourself, at any time.

**3. The cards are secret only while Kadena's clock behaves.** The wait between the close and
the drand number — 120 seconds at launch, a dial — is what keeps that number unpublished while betting is open.
It is sized against measured Kadena blocks, but that is a measurement of the past and an
assumption about the network, not something the contract can prove. **If the chain stopped
producing blocks for longer than the wait**, one round would be exposed: the one open when it
stopped, and only up to that round's own limit.

**4. A round can, in principle, stick.** If a drand number becomes permanently unavailable
*after* the contract has already seen a later one, that round can be neither settled nor
refunded, and everything reserved for it stays locked — the players' own stakes and the pot's
reserve — and, because coups are dealt in order, so does every round after it. The contract
itself would keep taking bets into that queue, so the page shows which round is waiting to be
dealt and which rounds wait behind it, and the helper's log says the same. This has never happened in drand's
history, but it is possible.

**5. Lowering the commission changes the house's own growth, not your odds.** At 5% the house's
bank grows on Banker bets; below about 3.5% at today's table share it would shrink (a simulation, not a rule). That is the
operator's capital and the operator's choice; it never reaches what a winning Banker bet in an
open round is paid.

**6. Two claims to the same account cannot go in one transaction.** A Kadena limitation.
Claim them separately.

---

## What we do not do

We do not hold your funds between rounds. Under the contract's rules there is no way to reverse
a bet, cancel a round you are winning, or change the odds after you have played: no correction,
no override and no undo — **a wrong bet stays wrong, and so does a winning one.** Nobody can
reset the shoe by hand: no such function exists. (Honest limit 1 is the exception, until the
contract is frozen.)

**What the operator can still do, said plainly.** There is no pause button and we are not
building one. A round that has opened runs to its end on the terms it opened with — nothing
we hold can change those terms or its outcome; until the freeze, honest limit 1 above says what the key could still replace. What we can do is stop **future** rounds, and the rest of an open round's betting (boards already placed are untouched): by withdrawing the bankroll,
or by raising the minimum bet or lowering the table limit for the rounds that follow. All the
dials stay ours after the contract is frozen — that is deliberate, and it is the cost of keeping
them tunable rather than fixing them in code forever. Any such change is a public transaction on
the chain.
