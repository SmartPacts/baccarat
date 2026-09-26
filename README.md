# Baccarat — Punto Banco on a public shoe, dealt by a number that did not exist when the bets closed

A Pact 5 smart contract for Kadena. A round opens the moment somebody places the first bet, takes
bets for a fixed window, and is then dealt from a random number produced by the **drand** beacon —
a group of independent organisations **outside Kadena entirely** — whose signature this contract
verifies on chain. **One signed transaction per player:** you place a board and that is all you
sign. The house sends no transaction inside a round and holds no secret.

> ## 🟢 DEPLOYED — Kadena mainnet (mainnet01)
>
> - Namespace `n_48867b242317a0216a67f8c7ca26696b5878e0e3`, **chain 2**, two modules:
>   `baccarat` (hash `nk8vteJTUYphFLy0hrMgoA_Sa89kaug5lxU_3IXB6eE`) and the beacon verifier
>   `drand` (hash `Y07t-duJmkXkcGth0TfBRg3ThbNR-uh9PdNUd1MKHBQ`), the same verifier the roulette
>   table already uses.
> - The code on chain is **character for character** the files in `deploy-bytes/`, which are in
>   turn the `(module …)` form of the annotated files in `pact/modules/` — comments and all.
>   Check both yourself with [`VERIFY.md`](VERIFY.md); it takes about a minute.
> - 🔴 **`baccarat` is not frozen.** Until it is, any **2 of the 3 governance keys** hold *module
>   admin*: in one transaction, with no new code and no change to the module hash, they can move
>   the pot and rewrite any record the contract keeps. They can also publish a new version.
>   Freezing ends all of that; it has not happened. **`drand` is already sealed** — its governance
>   is `(enforce false)` and it can never be upgraded.
> - **Nothing is for sale here.** This repository is source code.

Every transaction that built this deployment, with its request key and the reading that confirmed
it, is in [`deployments/mainnet01-chain-2.md`](deployments/mainnet01-chain-2.md).

## Which file am I reading?

| | |
|---|---|
| `pact/modules/baccarat.pact` | 🔴 **THE DEPLOYED CONTRACT, annotated.** Its `(module …)` form, comments and all, is the code stored on mainnet. The lines around it — header comments, the `namespace` line, a load-time check and the `create-table` footer — ran once, in the deploy transaction, and are not stored. |
| `pact/modules/drand.pact` | 🔴 **THE DEPLOYED BEACON VERIFIER**, same arrangement. Sealed on chain: it can never be upgraded. It was deployed once, for roulette, and baccarat uses that same module. |
| `deploy-bytes/` | exactly what the deploy transactions sent, sliced out of their own `cmd`. This is what `describe-module` returns today. It is *derived* from the files above, and CI re-derives it. |
| everything else | tests, vendored dependencies, the helper anyone can run, and the documents about all of it |

Nothing else in this repository deploys. The file in `pact/modules/` is kept exactly as it was
deployed, comments included, so a comment is never corrected in place.

## What is in here

```
pact/modules/     the two contracts
pact/tests/       eleven suites and two inverted controls that must FAIL; run-tests.sh runs
                  everything, including the gates
pact/vendor/      Kadena's coin + fungible interfaces, so the suite runs with no network
                  (not ours — see NOTICE)
deploy-bytes/     the exact bytes the deploy transactions carried, plus their sha256
deployments/      every mainnet transaction, with its request key and what confirmed it
docs/             BACCARAT-PLAYER-TERMS.md — the rules and everything that can go wrong,
                  twenty-four of its figures checked by CI against the contract source
                  (VERIFY.md §5); BACCARAT-WHAT-IT-DOES.md — the same in plain language,
                  GENERATED from the contract and the test results (VERIFY.md §5)
crank/            the helper that settles rounds and pays winners. Permissionless: it holds
                  no privilege, and anyone can run one
verification/     the recorded identity of the deployed artifact
.github/          the static gate, the checkers, and the CI that runs all of it on every push
```

## Run the tests yourself

Needs [Pact 5.4ce](https://github.com/kda-community/pact-5) on your PATH (or `PACT=/path/to/pact`)
and `python3`.

```
cd pact/tests && ./run-tests.sh
```

That is the same command CI runs, with no reduced subset — a CI that runs less than you do teaches
you to trust a green tick that means less than you think. It runs the static gate over every
source file, checks that `or`, `and` and `+` are always given exactly two operands (Pact 5 refuses
more only when the line runs), checks that no `expect-failure` was written with too few arguments
to assert *why* something failed, proves the annotated modules are the published deploy bytes,
proves the frozen-module fixture is this module with only its governance replaced, proves the
`drand` hash `baccarat` pins is the `drand` in this repository, proves the published terms state
the contract's own constants — and then runs the eleven suites, scoring each by **exit code**
rather than by grepping the transcript.

It also runs two files that **must fail**, each scored on the exit code *and* on the refusal
message, because any unrelated breakage also exits 1:

- `baccarat-pin-must-fail.repl` plants an impostor `drand` that "verifies" every signature and
  returns a seed — and so the cards — of the attacker's choosing, and `baccarat` must refuse to
  load against it.
- `baccarat-open-round-must-fail.repl` names an `open-round` export. A round is opened by the
  first bet and by nothing else, so the module has no such export, and a module that calls one
  must fail to load.

## How the cards are chosen

When a round opens, the contract computes a drand round number a fixed wait after betting closes
and pins it into the round. That beacon **does not exist while a bet can still be placed** — not
to a player, not to a miner, not to the operator. When it is published, **anyone** may submit it:
the contract checks the BN254 pairing itself, so a forged one cannot verify, and drand values
never expire, so there is no capture window to miss and nothing to gain from staying silent.

**The shoe is a pool, not an order.** Eight decks, 416 cards, kept on chain as a count per card
kind. Each card of a coup is drawn by hashing the coup's beacon with the card's position and
walking the counts, so the pool's composition is public but the next card does not exist until the
beacon does. Cards leave the pool as they are dealt; when the pool reaches the cut card it is
refilled before the next coup. Coups are dealt **in round order** — a later round is refused until
the earlier one is settled — so the pool a coup draws from never depends on who settled first. The
deal itself follows the official Punto Banco tableau, and the rules suite checks every cell.

**Why not a Kadena block hash.** Whoever mines the deciding block would see the cards before
publishing it and could throw the block away and keep mining — a free re-roll. Combining several
future blocks does not help, because the first N−1 already exist when the last is mined. drand is
produced off Kadena, so no Kadena miner touches it.

## The dials the operator holds, and their bounds

`set-params` is the only setter, it is gated on the governance keyset, and it reaches **future
rounds only**: a round that has opened keeps the share, the minimum, the commission, the cut, the
window and the beacon it was given. The bounds below are constants in the module and cannot be
widened by any call.

| dial | today | bound in the code |
|---|---|---|
| share of the spare pot one round may risk | 2% | greater than 0, at most 100% — a round cannot risk more than the whole spare pot |
| table minimum | 0.01 KDA | never below 0.001 KDA |
| target float (where the fee stops ramping) | 30,000 KDA | must be positive |
| betting window | 120 s | 30 s to 1 hour |
| wait between close and beacon | 120 s | never below 60 s, never above 1 hour |
| Banker commission | 5% | never below 2.6932% — where the Banker bet's house edge reaches zero — never above 100% |
| cut card (the pool is refilled at or below it) | 52 cards | 14 cards to a full shoe of 416 |

The dials are day-to-day settings, not upgrade authority: they are gated on a separate
capability from the one a freeze removes, so they stay the operator's after the contract is
frozen, inside the same bounds.

Three things are **not** dials and no key can move them: the Player and Tie payouts (1 to 1 and 8
to 1), the rules of the deal, and the fee ceiling. The fee is paid out of the pot — it never
touches a player's stake — at each bet's own house edge, scaled by `min(1, available /
target-float)`, so the pot fills to its target and then forwards the whole edge. The edge is the
immutable ceiling, because charging more would give the pot negative drift.

| bet | pays | player return | house edge |
|---|---|---|---|
| Player | 1 to 1, returned on a tie | 98.765% | 1.2351% |
| Banker | 0.95 to 1 at today's 5% commission, returned on a tie | 98.942% | 1.0579% |
| Tie | 8 to 1 | 85.640% | 14.3596% |

## What this contract's code does not do

Every line below describes the deployed code. Until `baccarat` is frozen, the governance keys can
override any of it (the box at the top).

- **It cannot pick a card.** No function lets anyone choose one; every card is drawn from a drand
  signature the contract verifies, and a wrong signature does not verify.
- **It cannot settle from a different verifier.** `baccarat` pins `drand` by hash, so it refuses
  to load against any other code under that name. `baccarat-pin-must-fail.repl` is that proof.
- **It cannot reshuffle by hand or deal out of order.** The pool is refilled by the contract at
  the cut card and by nothing else, and round two is never dealt before round one.
- **It cannot run short.** Each round carries a 3-slot exposure vector — what the pot owes if
  Player, Banker or Tie wins — and reserves the true worst case over every board in it. It can
  only refuse a bet, never fail to pay one.
- **It does not make a loser send a transaction.** A losing board's reserve is released by the
  settlement itself.
- **It does not strand a round whose beacon never arrives.** After 90 days a round nobody could
  settle can be voided, and every stake comes back.
- **Settling is nobody's privilege.** Submitting the beacon and paying a winner are calls anybody
  can make, and the caller gets no say in the outcome. That is why a bot can do it — see
  [`crank/`](crank/), which is here so that anyone can run one.

## Reporting a problem

See [SECURITY.md](SECURITY.md) — open a **GitHub security advisory** on this repository.

## Licence

Apache-2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
