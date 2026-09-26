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
| — | ⏳ **proof rounds — pending.** Two small rounds with real money, settled and paid on chain, have not run yet. Until they have, `(get-params)` reads `round-seq: 0` (read back 2026-09-26) | — | — | — | — |

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
