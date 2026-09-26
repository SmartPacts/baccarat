# Deployment — Kadena mainnet01, chain 2

Every line here is on chain. Each request key links to a public explorer; each row says what the
transaction did and the read-only call that confirms it today. Nothing in this file is a claim you
have to take from us — the calls are free, need no key, and can be run against any node.

Where a row says "read back 2026-09-26", we ran that call against
`https://chainweb.eckowallet.com`, on that date, and the value below is what came back. Every
request key's gas, block and result below was read from the same node's `/poll` on that date.

**Who signs.** Everything gated on governance was signed by **two of the three governance keys**
(`n_48867b242317a0216a67f8c7ca26696b5878e0e3.spt-gov`, predicate `keys-2`), plus a separate key
that only pays gas. There is no one-key path to any of it.

---

## 1. The contracts

| date | what it did | request key | gas | block | confirmed by |
|---|---|---|---:|---:|---|
| 2026-09-22 | deploy `drand`, the beacon verifier — sealed at deploy, `(enforce false)` governance. Deployed for the roulette table; baccarat deployed no verifier of its own and uses this one | [`niHtcnxu0iN8eFWCZjAtZ_sK1H6GpNrXc5bCK8hznqI`](https://explorer.chainweb-community.org/mainnet/tx/niHtcnxu0iN8eFWCZjAtZ_sK1H6GpNrXc5bCK8hznqI) | 16,943 | 7252453 | its result is `Loaded module …drand, hash Y07t-duJmkXkcGth0TfBRg3ThbNR-uh9PdNUd1MKHBQ` — the same hash `baccarat` pins, and the same one you get building `pact/modules/drand.pact` locally |
| 2026-09-26 | deploy `baccarat` and create its four tables | [`VHSvyzj5TB5v-p2Fwm0NBsiYZnchKW09AkWSclmDLJQ`](https://explorer.chainweb-community.org/mainnet/tx/VHSvyzj5TB5v-p2Fwm0NBsiYZnchKW09AkWSclmDLJQ) | 60,264 | 7263915 | result `TableCreated`; `describe-module` returns exactly `deploy-bytes/baccarat.pact`, 40,913 characters, module hash `nk8vteJTUYphFLy0hrMgoA_Sa89kaug5lxU_3IXB6eE` — see [VERIFY.md](../VERIFY.md) §1. Read back 2026-09-26 |

The `cmd` of the `baccarat` deploy transaction carries the code that was sent.
`deploy-bytes/baccarat.pact` is the `(module …)` region sliced out of it, and CI proves it is still
the module in `pact/modules/`. `deploy-bytes/drand.pact` is the same slice of the `drand` deploy.

## 2. Setting it up

| date | what it did | request key | gas | block | confirmed by |
|---|---|---|---:|---:|---|
| 2026-09-26 | `initialize` — names where the fee goes, once, sets the target float, and lays out a fresh shoe | [`wEy55xNZ_WqUewvREQ1zMpo8wkBioWe5gE-XZANr2X0`](https://explorer.chainweb-community.org/mainnet/tx/wEy55xNZ_WqUewvREQ1zMpo8wkBioWe5gE-XZANr2X0) | 511 | 7263924 | result `baccarat initialized`; `(get-params)` → `revenue: "m:n_48867b242317a0216a67f8c7ca26696b5878e0e3.SPT:SPT-funding"`, `target-float: 30000`; `(shoe-status)` → `remaining: 416`, `decks: 8`, `shoe-no: 1`. Read back 2026-09-26 |
| 2026-09-26 | `fund-house` — 15,000 KDA into the pot | [`lb75LtqUroZgXKOFTa33tVAJ9Th_REz1vIUem5RmM9w`](https://explorer.chainweb-community.org/mainnet/tx/lb75LtqUroZgXKOFTa33tVAJ9Th_REz1vIUem5RmM9w) | 308 | 7263933 | result `house funded`; `(coin.get-balance "m:n_48867b242317a0216a67f8c7ca26696b5878e0e3.baccarat:baccarat-pot")` → `15000`. Read back 2026-09-26 |

The pot is `m:n_48867b242317a0216a67f8c7ca26696b5878e0e3.baccarat:baccarat-pot`, a module-guarded
account: no key holds it directly. It was funded from the company account
`r:n_48867b242317a0216a67f8c7ca26696b5878e0e3.spt-gov`.

## 3. Where the capital came from

The pot's 15,000 KDA is SPT sale proceeds, which live on **chain 0**. Moving them to chain 2 took
a 1 KDA rehearsal and then the real transfer — all on 2026-09-26, all on chain 0. A cross-chain
transfer's request key names the chain-0 half; the continuation lands on chain 2. The rehearsal's
1 KDA and the transfer's 14,999 KDA add up to the 15,000 that `fund-house` then moved from
`r:…spt-gov` into the pot.

| what it did | request key | gas | block | result |
|---|---|---:|---:|---|
| 1 KDA rehearsal withdrawal from the sale proceeds | [`jDbuxa0KagxRlcHZEn4Ytcwg-LOOxZKbl7jHfczBSoM`](https://explorer.chainweb-community.org/mainnet/tx/jDbuxa0KagxRlcHZEn4Ytcwg-LOOxZKbl7jHfczBSoM) | 309 | 7263867 | `proceeds withdrawn` — 1 KDA to `r:…spt-gov` |
| 1 KDA cross-chain rehearsal, chain 0 → 2 | [`laU-9bNbmhuPDL24BUtjb11iV5qtfApWtEbis50C_gE`](https://explorer.chainweb-community.org/mainnet/tx/laU-9bNbmhuPDL24BUtjb11iV5qtfApWtEbis50C_gE) | 344 | 7263878 | 1 to `r:…spt-gov`, source chain 0, target chain 2 |
| 14,999 KDA withdrawal from the sale proceeds | [`G5awgWDqadjrqKPc9hd6Yr2dIURzlt_xU_5TpPQyjkc`](https://explorer.chainweb-community.org/mainnet/tx/G5awgWDqadjrqKPc9hd6Yr2dIURzlt_xU_5TpPQyjkc) | 309 | 7263893 | `proceeds withdrawn` — 14,999 KDA to `r:…spt-gov` |
| 14,999 KDA cross-chain, chain 0 → 2 | [`kXodcNSiBbUHxFSWF3g7Nil7UGp4sj_RSkGyb-5F_xE`](https://explorer.chainweb-community.org/mainnet/tx/kXodcNSiBbUHxFSWF3g7Nil7UGp4sj_RSkGyb-5F_xE) | 344 | 7263900 | 14,999 to `r:…spt-gov`, source chain 0, target chain 2 |

**The helper accounts.** Two bot accounts were funded 5 KDA each, on chain 2:
[`qHJx4UE7MDOFLC6Z9orry-Ou4Uxfcgz7x5d2vpvkJY0`](https://explorer.chainweb-community.org/mainnet/tx/qHJx4UE7MDOFLC6Z9orry-Ou4Uxfcgz7x5d2vpvkJY0)
(block 7263814) and
[`vrD-HXcszJRVpJA756QnEG9GFeaoaAKeeHvhw6JHlsA`](https://explorer.chainweb-community.org/mainnet/tx/vrD-HXcszJRVpJA756QnEG9GFeaoaAKeeHvhw6JHlsA)
(block 7263815), 235 gas each. They are
`k:e338ab566fbdab007c777d76a86d4db499a8bc48882de0129f5511420816967d` and
`k:4b2af89367b841def981a386385433ebfc1fa4d0d8a34f6fdfd3ddccd02c6ba6`; `coin.get-balance` returns
`5` for each (read back 2026-09-26). They hold **no privilege the contract recognises**: they pay
gas to submit beacons and to send winners their money, which is something anyone may do. Their
5 KDA is gas money, not house money, and it is not in the pot.

## 4. Proving it works, with real money

| date | what it did | request key | gas | block | confirmed by |
|---|---|---|---|---|---|
| 2026-09-26 | proof round 1 — a throwaway account places the minimum board, 0.01 KDA on Player, which opens round 1 | [`1Fkdox9CtzTzlLbHlk_4lkbeqOZCL4CPPeEYpOd9Rm8`](https://explorer.chainweb-community.org/mainnet/tx/1Fkdox9CtzTzlLbHlk_4lkbeqOZCL4CPPeEYpOd9Rm8) | 793 | 7264005 | `(get-round 1)` — its board, its beacon round 20979889 |
| 2026-09-26 | round 1 dealt by the helper from drand round 20979889: Banker (Player 3C QD 10C, Banker 3D 9D 4S). The same transaction pays the round's fee, 0.000061754066 KDA, to the SPT funding account (`FEE-PAID` event) | [`8ZRENN9joAfvC34uvLik4MohbMcy7pRdVYAximDTv3g`](https://explorer.chainweb-community.org/mainnet/tx/8ZRENN9joAfvC34uvLik4MohbMcy7pRdVYAximDTv3g) | 2,563 | 7264013 | `(get-round 1)` → `"resolved"`, winner `"banco"`, `fee-owed` 0 |
| 2026-09-26 | proof round 2 — the same account, the same minimum board on Player | [`D6BxjZPV9j7wl7jBc9aY3rPKZ3qvwu_EiKkNdW5qwX4`](https://explorer.chainweb-community.org/mainnet/tx/D6BxjZPV9j7wl7jBc9aY3rPKZ3qvwu_EiKkNdW5qwX4) | 846 | 7264016 | `(get-round 2)` |
| 2026-09-26 | round 2 dealt from drand round 20980013: Banker with a natural 8 (Player AS 2H, Banker 10C 8D); fee 0.000061754107 KDA paid (`FEE-PAID`), equal to the `fee-owed` the round carried before the deal, to the last digit | [`Or7czI-uhRSRTXyey3AjOOmpNSNEYRhFnuWgCifg3-o`](https://explorer.chainweb-community.org/mainnet/tx/Or7czI-uhRSRTXyey3AjOOmpNSNEYRhFnuWgCifg3-o) | 3,291 | 7264023 | `(get-round 2)`; `(coin.get-balance "m:n_48867b242317a0216a67f8c7ca26696b5878e0e3.SPT:SPT-funding")` moved by exactly that amount |
| 2026-09-26 | proof round 3 — a fresh throwaway, `k:c3bdac88…`, bets 0.01 on Player, 0.01 on Banker and 0.01 on Tie in one board (every outcome pays something), then is swept to EXACTLY 0 KDA by an ordinary coin transfer whose gas another key paid, and signs nothing further | [`-FbMe4lcuvKJdrLJ8SB0hUqcr9nBpwvkIb2qw56n1kY`](https://explorer.chainweb-community.org/mainnet/tx/-FbMe4lcuvKJdrLJ8SB0hUqcr9nBpwvkIb2qw56n1kY) | 844 | 7264028 | `(round-boards 3)` — one board, stake 0.03; `(coin.details "k:c3bdac88d777e352e3c1c1e066cfcba2719aa058b3a80e4b722aa06e31f5903b")` |
| 2026-09-26 | round 3 dealt from drand round 20980131: Banker (Player 4H 8C 10C, Banker QS 4S); fee 0.000832631897 KDA paid (`FEE-PAID`) | [`1NzJT1DvC9dYtHAN1zZcmhunRnZw7XHDMUeWgq5VW4A`](https://explorer.chainweb-community.org/mainnet/tx/1NzJT1DvC9dYtHAN1zZcmhunRnZw7XHDMUeWgq5VW4A) | 2,585 | 7264036 | `(get-round 3)` → `"resolved"`, winner `"banco"` |
| 2026-09-26 | the helper pays the winner: 0.0195 KDA (the Banker box, 0.01 at 0.95 to 1, stake returned) to an account that held 0 KDA and signed nothing — `CLAIMED` event | [`r0cadSScuZ9cqXyI8gTsH887Kp4ucStKsFgDM3z7EE4`](https://explorer.chainweb-community.org/mainnet/tx/r0cadSScuZ9cqXyI8gTsH887Kp4ucStKsFgDM3z7EE4) | 500 | 7264037 | `(round-boards 3)` → `claimed` true; `(coin.get-balance "k:c3bdac88d777e352e3c1c1e066cfcba2719aa058b3a80e4b722aa06e31f5903b")` = 0.0195 |

After the three coups the pot reads 15,000.029543859930 KDA (the losing stakes of rounds 1 and 2 and the Player and Tie stakes of round 3 stayed in it; the fees left it), `reserved` 0, and the shoe stands at 401 of 416 cards after 3 coups. Every one of these rows was read back from the chain on 2026-09-26; the helper that dealt and paid runs on the operator's machines from `crank/` and signs only its own gas.

## 5. The dials at launch

No `set-params` has been sent. The dials are the launch values `initialize` wrote:

`(get-params)` → `reserve-fraction: 0.02`, `min-bet: 0.01`, `target-float: 30000`,
`bet-window: 120`, `drand-margin: 120`, `commission: 0.05`, `cut-card: 52`. Read back 2026-09-26.

Every future change to them will be a row here, with its transaction. A change reaches **future
rounds only**: a round that has already opened keeps the share, the minimum, the commission, the
cut, the window and the beacon it was given.

---

## Reading it yourself

```lisp
(n_48867b242317a0216a67f8c7ca26696b5878e0e3.baccarat.get-params)
(n_48867b242317a0216a67f8c7ca26696b5878e0e3.baccarat.pot-status)
(n_48867b242317a0216a67f8c7ca26696b5878e0e3.baccarat.shoe-status)
(n_48867b242317a0216a67f8c7ca26696b5878e0e3.baccarat.get-round 1)
(coin.get-balance "m:n_48867b242317a0216a67f8c7ca26696b5878e0e3.baccarat:baccarat-pot")
(describe-keyset "n_48867b242317a0216a67f8c7ca26696b5878e0e3.spt-gov")
```

All read-only, all free, from any node on mainnet01 chain 2 — with `/local`, with Chainweaver, or
with `.github/scripts/fetch-onchain.py` as a worked example of building the request.
`get-round 1` fails until the first round has been played.
