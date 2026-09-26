;; baccarat.pact — Punto Banco on a public, depleting shoe (Pact 5 / KDA-CE).
;;
;; ONE SIGNED TRANSACTION PER PLAYER. You place a board -- Player, Banker, Tie, any
;; mix -- and that is all you sign. If you win you claim; if you lose you do
;; nothing. Anyone may claim for a winner, and the payment always goes to the
;; account that placed the board.
;;
;; WHERE THE CARDS COME FROM. Each coup is dealt by a drand BN254 beacon verified
;; on chain by `n_48867b242317a0216a67f8c7ca26696b5878e0e3.drand`, never by a
;; Kadena block hash: the miner of a deciding block would see the outcome before
;; publishing and could discard the block, a free re-roll. The round's beacon is
;; pinned when the round opens and is not published until a fixed wait after
;; betting closes, so nobody -- player, miner or operator -- can know a card while
;; a bet can still be placed. Afterwards ANYONE may submit the beacon; a forged one
;; cannot verify, and drand values never expire, so a beacon can be submitted at
;; any time; a round is refunded only after ninety days with no beacon at or after
;; its own seen.
;;
;; THE SHOE IS A POOL, NOT AN ORDER. Eight decks, 416 cards, kept as a count per
;; card kind. A card is drawn by hashing the coup's seed with the card's position
;; and walking the counts, so the pool's composition is public but the next card
;; does not exist until the beacon does. When the pool runs down to the cut card
;; it is refilled BEFORE the coup is dealt, and coups are dealt in round order so
;; the pool a coup draws from never depends on who settled first. What a public
;; pool exposes is its composition: anyone may compute the exact odds of the next
;; coup from the cards left, and a front end is invited to show them to everyone.
;; Measured over 2,000 shoes at the launch cut of one deck, a perfect counter
;; betting the round's cap gains about 0.002 KDA per shoe; nothing above it.
;;
;; NO HOUSE INPUT. No house secret, no per-round house transaction.
;;
;; SOLVENCY IS STRUCTURAL. Each round carries a 3-slot EXPOSURE VECTOR: what the
;; house owes if Player, Banker or Tie wins, every payout floored to coin precision
;; where it is added and floored the same way where it is paid, so a fully claimed
;; round returns `reserved` to exactly zero. The round reserves max(exposure) --
;; the true worst case over every board in it -- so the pot can never be short. It
;; can only refuse a bet. At resolve the liability is one lookup and the rest is
;; released, which is why a LOSER never sends a transaction.
;;
;; THE FEE NEVER TOUCHES THE PLAYER. It is paid out of the POT and decides only how
;; much of the house's own edge is forwarded to the SPT treasury: per bet type, at
;; that bet's exact house edge, scaled by min(1, available / target-float), so the
;; pot fills to its target and then forwards the whole edge. A fee above the edge
;; would give the pot negative drift, which is why the edge is the ceiling.
;;
;; THE DIALS. The share of the spare pot one coup may risk, the table minimum, the
;; betting window, the wait before the beacon, the Banker commission and the cut
;; card are OPERATOR INPUTS for the life of the module: `set-params` is gated on
;; ADMIN, not GOVERNANCE, so they still move after a freeze. A live round keeps
;; the share, the minimum, the commission, the cut, its window and its beacon;
;; the fee's ramp reads the pot's health against the target NOW, by design, so a
;; target moved mid-round changes the fee accrued by later boards, and with it the
;; room the round has left under its limit. Bounds the contract keeps: the share is arithmetic
;; (0, 1]; the minimum has a floor at the cost of paying one winner; the wait has a
;; floor, because a wait shorter than a block gap lets anyone bet on a published
;; beacon; the commission has a floor at the value where the Banker bet's house
;; edge is zero, because below it the pot pays out more than it expects to win; the
;; cut has a floor at 14 cards, the deepest cut a gaming regulation asks for, where a
;; card counter's take is measured at 0.65 KDA a shoe. Everything above a floor is the operator's judgement, disclosed.
;;
;; A DRAND STALL REFUNDS; IT DOES NOT FORFEIT. After ninety days of total silence
;; a round may be voided and every stake claimed back, but only while the module
;; has verified no beacon at or after the round's own: `last-beacon` is the record,
;; and one `prove-liveness` call keeps every pending round un-voidable.
;;
;; FRESH DEPLOY ONLY. Adding a schema field does not fail at upgrade; it breaks at
;; the first read of the new field. Verify the target chain carries no rows.

(namespace "n_48867b242317a0216a67f8c7ca26696b5878e0e3")

; Load-time admin gate: deploying or upgrading this file requires the spt-gov
; keyset, which already exists on every mainnet chain. Rotating it rotates this
; module's admin with it.
(enforce-guard (keyset-ref-guard "n_48867b242317a0216a67f8c7ca26696b5878e0e3.spt-gov"))

(module baccarat GOVERNANCE

  @doc "Punto Banco on a public, depleting shoe: one signed transaction per player, \
  \each coup dealt from a verified drand beacon, winners claim. The fee is the pot's \
  \and never touches a player's return."

  (use coin)
  ; Sealed, tableless, pure -- and PINNED BY CODE HASH. This module refuses to
  ; load against any other bytes under that name, so the beacon verifier cannot
  ; be swapped for one that hands out chosen cards.
  (use n_48867b242317a0216a67f8c7ca26696b5878e0e3.drand "Y07t-duJmkXkcGth0TfBRg3ThbNR-uh9PdNUd1MKHBQ"
    [ verified-seed round-at time-of-round ])

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CARDS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; The specification of a card's value: A = 1, 2-9 face, 10/J/Q/K = 0. Written
  ; out in full so it is readable as a table; the unit suite pins it, kind by kind,
  ; against an independent list.
  (defconst VALUE-OF
    { "AS": 1, "AH": 1, "AD": 1, "AC": 1
    , "2S": 2, "2H": 2, "2D": 2, "2C": 2
    , "3S": 3, "3H": 3, "3D": 3, "3C": 3
    , "4S": 4, "4H": 4, "4D": 4, "4C": 4
    , "5S": 5, "5H": 5, "5D": 5, "5C": 5
    , "6S": 6, "6H": 6, "6D": 6, "6C": 6
    , "7S": 7, "7H": 7, "7D": 7, "7C": 7
    , "8S": 8, "8H": 8, "8D": 8, "8C": 8
    , "9S": 9, "9H": 9, "9D": 9, "9C": 9
    , "10S": 0, "10H": 0, "10D": 0, "10C": 0
    , "JS": 0, "JH": 0, "JD": 0, "JC": 0
    , "QS": 0, "QH": 0, "QD": 0, "QC": 0
    , "KS": 0, "KH": 0, "KD": 0, "KC": 0 })

  (defconst RANKS:[string] ["A" "2" "3" "4" "5" "6" "7" "8" "9" "10" "J" "Q" "K"])
  (defconst SUITS:[string] ["S" "H" "D" "C"])

  ; The 52 card kinds in pool order: index = 4 * rank + suit.
  (defconst KINDS:[string]
    (fold (+) [] (map (lambda (r:string) (map (lambda (s:string) (+ r s)) SUITS)) RANKS)))
  (defconst KIND-COUNT:integer 52)
  (defconst DECKS:integer 8)
  (defconst SHOE-SIZE:integer 416)
  (defconst FULL-SHOE:[integer] (make-list KIND-COUNT DECKS))
  ; A coup never needs more than six cards: four, a player's third, a banker's third.
  (defconst CARDS-PER-COUP:integer 6)

  (defconst PUNTO:string "punto")
  (defconst BANCO:string "banco")
  (defconst TIE:string "tie")

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ECONOMICS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; The exact eight-deck probabilities of each outcome, as integer fractions from
  ; an exhaustive enumeration of every coup a fresh shoe can deal (339,400 coups),
  ; held at 30 places -- far beyond coin precision -- so that every edge derived
  ; below and FLOORED at 12 places never exceeds the exact fraction. The
  ; probabilities are never written as decimal literals; the Tie payout, the
  ; dials' launch values and bounds, the void wait and the bankroll divisor are,
  ; and the suites pin each one.
  (defconst P-PUNTO:decimal (round (/ (dec 8712962041376) (dec 19524993263685)) 30))
  (defconst P-BANCO:decimal (round (/ (dec 8954111587648) (dec 19524993263685)) 30))
  (defconst P-TIE:decimal   (round (/ (dec 619306544887) (dec 6508331087895)) 30))

  ; Player pays 1:1 and pushes on a tie; Tie pays 8:1. Their edges are fixed.
  (defconst PUNTO-EDGE:decimal (floor (- P-BANCO P-PUNTO) 12))
  (defconst TIE-PAYS:decimal 8.0)
  (defconst TIE-EDGE:decimal (floor (- 1.0 (* (+ TIE-PAYS 1.0) P-TIE)) 12))

  ; Banker pays (1 - commission):1 and pushes on a tie, so its edge moves with the
  ; commission dial. The floor is the commission at which that edge is zero, rounded
  ; UP: below it the pot pays out more on Banker than it expects to win.
  (defconst LAUNCH-COMMISSION:decimal 0.05)
  (defconst MIN-COMMISSION:decimal (ceiling (- 1.0 (/ P-PUNTO P-BANCO)) 12))
  (defconst MAX-COMMISSION:decimal 1.0)

  ; The share of the spare pot one coup may put at risk. Bounded arithmetically
  ; only: a coup cannot risk more than the pot has spare. The launch value sits
  ; under every family's zero-growth crossing (Banker's, the smallest, is 0.048).
  (defconst LAUNCH-RESERVE-FRACTION:decimal 0.02)
  (defconst MAX-RESERVE-FRACTION:decimal 1.0)

  ; The table minimum and its floor: paying one winner costs about 500 gas, so
  ; at a hundredfold gas price 0.001 is twice the cost of settling the bet.
  (defconst LAUNCH-MIN-BET:decimal 0.01)
  (defconst MIN-BET-FLOOR:decimal 0.001)

  (defconst LAUNCH-BET-WINDOW:decimal 120.0)
  (defconst MIN-BET-WINDOW:decimal 30.0)
  (defconst MAX-BET-WINDOW:decimal 3600.0)

  ; The wait between the close and the beacon. Pact's block-time is the PARENT
  ; block's, so a bet accepted at the close can still be mined a whole block gap
  ; later; a beacon published inside that gap could be bet on by anyone. The floor
  ; is where 7% of measured chain-2 block gaps would exceed it.
  (defconst LAUNCH-DRAND-MARGIN:decimal 120.0)
  (defconst MIN-DRAND-MARGIN:decimal 60.0)
  (defconst MAX-DRAND-MARGIN:decimal 3600.0)

  ; The cut card: the pool is refilled before a coup when this many cards or fewer
  ; remain. At the ceiling every coup is dealt from a fresh shoe.
  (defconst LAUNCH-CUT:integer 52)
  (defconst MIN-CUT:integer 14)
  (defconst MAX-CUT:integer SHOE-SIZE)

  ; The pot is sized to keep an advertised even-money maximum of pot/250 through a
  ; year of play; a larger maximum is accepted on any single coup, up to the cap.
  (defconst BANKROLL-DIVISOR:decimal 250.0)

  ; How long everyone must stay silent before a refund opens: ninety days.
  (defconst VOID-AFTER:decimal 7776000.0)

  (defconst PREC:integer 12)
  (defconst GAME-KEY:string "baccarat")
  (defconst SHOE-KEY:string "shoe")

  ; The pot's guard is a MODULE guard: it passes only while this module is on the
  ; call stack and otherwise falls through to module admin, which is GOVERNANCE,
  ; which is `enforce false` once frozen. That holds on every engine version.
  ; Consequences: until the freeze module admin can spend the pot; the module can
  ; never be renamed; the account is fixed at first funding; and the engine marks
  ; `create-module-guard` deprecated (a load-time warning), kept here because it
  ; is the one permissionless custody that survives a freeze.
  (defun pot-guard:guard () (create-module-guard "baccarat-pot"))
  (defconst HOUSE_ACCOUNT:string (create-principal (pot-guard)))

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CAPABILITIES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; UPGRADE AUTHORITY ONLY. Freezing this module replaces this body with
  ; (enforce false) and changes nothing else, which is only true while no
  ; operational function depends on it: they all use ADMIN.
  (defcap GOVERNANCE ()
    (enforce false "this module is frozen: it can never be upgraded"))

  ; Operational authority: initialize, set-params, withdraw-house. The same keyset
  ; as GOVERNANCE, deliberately a different capability, so a freeze strands nothing.
  (defcap ADMIN ()
    (enforce-guard (keyset-ref-guard "n_48867b242317a0216a67f8c7ca26696b5878e0e3.spt-gov")))

  (defcap BET-PLACED:bool     (account:string seq:integer stake:decimal reserve:decimal) @event true)
  (defcap ROUND-OPENED:bool   (seq:integer close-time:time drand-round:integer) @event true)
  (defcap COUP-RESULT:bool    (seq:integer winner:string drand-round:integer punto:[string] banco:[string]) @event true)
  (defcap SHOE-SHUFFLED:bool  (seq:integer shoe-no:integer) @event true)
  (defcap CLAIMED:bool        (account:string seq:integer amount:decimal) @event true)
  (defcap ROUND-VOID:bool     (seq:integer stake:decimal) @event true)
  (defcap LIVENESS-PROVEN:bool (drand-round:integer) @event true)
  (defcap FEE-PAID:bool       (seq:integer amount:decimal to:string) @event true)
  (defcap HOUSE-FUNDED:bool   (funder:string amount:decimal) @event true)
  (defcap HOUSE-WITHDRAWN:bool (to:string amount:decimal) @event true)
  (defcap PARAMS-SET:bool     (reserve-fraction:decimal min-bet:decimal target-float:decimal
                               bet-window:decimal drand-margin:decimal commission:decimal
                               cut-card:integer) @event true)
  (defcap INITIALIZED:bool    (revenue:string) @event true)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; SCHEMAS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (defschema wager
    @doc "A board: what is staked on Player, Banker and Tie, and the highest Banker commission the player accepts. Any stake may be zero; the total must reach the round's minimum."
    punto:decimal
    banco:decimal
    tie:decimal
    commission:decimal)

  (defschema game
    last-beacon:integer      ; highest drand round this module has ever VERIFIED
    round-seq:integer        ; last round opened
    current:integer          ; the round currently taking bets, 0 = none
    reserved:decimal         ; total locked across every unsettled round
    revenue:string           ; SPT treasury account, set once at initialize
    reserve-fraction:decimal
    target-float:decimal
    bet-window:decimal
    min-bet:decimal
    drand-margin:decimal
    commission:decimal
    cut-card:integer)

  (defschema shoe
    counts:[integer]         ; cards remaining of each kind, in KINDS order
    remaining:integer
    shoe-no:integer          ; how many shoes so far; 1 is the first
    dealt-since:integer      ; coups dealt from this shoe
    shoe-seq:integer)        ; the last round dealt or voided: coups go in round order

  (defschema coup
    avail-at-open:decimal
    frac-at-open:decimal
    min-bet-at-open:decimal
    commission-at-open:decimal
    cut-at-open:integer
    close-time:time
    drand-round:integer
    exposure:[decimal]       ; 3 slots: what the house owes if Player, Banker, Tie wins
    stake:decimal
    fee-owed:decimal
    reserve:decimal          ; max(max(exposure), stake) + fee-owed
    state:string             ; "open" | "resolved" | "void"
    winner:string            ; "" until dealt
    punto:[string]
    banco:[string]
    liability:decimal)

  (defschema board
    seq:integer
    account:string
    punto:decimal
    banco:decimal
    tie:decimal
    stake:decimal
    claimed:bool)

  (deftable game-table:{game})
  (deftable shoe-table:{shoe})
  (deftable rounds:{coup})
  (deftable boards:{board})

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; HELPERS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (defun curr-time:time () (at 'block-time (chain-data)))
  (defun rkey:string (seq:integer) (int-to-str 10 seq))
  (defun bkey:string (seq:integer account:string) (format "{}|{}" [seq account]))

  (defun vmax:decimal (v:[decimal])
    (fold (lambda (a:decimal b:decimal) (if (> b a) b a)) 0.0 v))

  (defun enforce-prec:bool (x:decimal what:string)
    (enforce (= (floor x PREC) x) (format "{} exceeds {} decimal places" [what PREC])))

  (defun card-value:integer (card:string) (at card VALUE-OF))

  (defun hand-total:integer (hand:[string])
    @doc "The baccarat total of a hand: the sum of its card values, modulo ten."
    (mod (fold (+) 0 (map (card-value) hand)) 10))

  (defun banco-edge:decimal (commission:decimal)
    @doc "The house edge of a Banker bet at a given commission, floored to coin precision; zero at MIN-COMMISSION."
    (floor (- P-PUNTO (* (- 1.0 commission) P-BANCO)) PREC))

  ; Gross payouts per bet, floored where they are not exact. The same functions
  ; feed the exposure vector and the claim, which is what keeps the two equal.
  (defun pay-punto:decimal (p:decimal) (* 2.0 p))
  (defun pay-banco:decimal (b:decimal commission:decimal)
    (+ b (floor (* b (- 1.0 commission)) PREC)))
  (defun pay-tie:decimal (t:decimal) (* (+ TIE-PAYS 1.0) t))

  (defun board-vector:[decimal] (p:decimal b:decimal t:decimal commission:decimal)
    ; a tie pays the Tie bet and pushes the Player and Banker stakes back
    [ (pay-punto p) (pay-banco b commission) (+ (pay-tie t) (+ p b)) ])

  (defun slot:integer (winner:string)
    (cond ((= winner PUNTO) 0) ((= winner BANCO) 1) ((= winner TIE) 2)
          (enforce false "not an outcome")))

  (defun board-payout:decimal (p:decimal b:decimal t:decimal commission:decimal winner:string)
    @doc "What a board is owed when `winner` wins, at the round's commission."
    (at (slot winner) (board-vector p b t commission)))

  ; The fee ramps with the pot's health and never exceeds the bet's own edge.
  (defun fee-scale:decimal (available:decimal target:decimal)
    (enforce (> target 0.0) "target float must be positive")
    (if (>= available target)
        1.0
        (floor (/ (if (> available 0.0) available 0.0) target) PREC)))

  (defun fee-for:decimal (p:decimal b:decimal t:decimal commission:decimal scale:decimal)
    (floor (* scale (+ (* PUNTO-EDGE p) (+ (* (banco-edge commission) b) (* TIE-EDGE t)))) PREC))

  (defun validate-wager:decimal (w:object{wager})
    @doc "Check every stake and return the board's total."
    (let ((p (at 'punto w)) (b (at 'banco w)) (t (at 'tie w)))
      (enforce (and (>= p 0.0) (and (>= b 0.0) (>= t 0.0))) "every stake must be non-negative")
      (enforce-unit p) (enforce-unit b) (enforce-unit t)
      (+ p (+ b t))))

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; THE DEAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; The kind at cumulative index r in the pool: walk the counts carrying {cum, found}.
  (defun kind-at:integer (counts:[integer] r:integer)
    (at 'found
      (fold (lambda (acc:object idx:integer)
              (let ((cum (at 'cum acc)) (n (at idx counts)))
                (if (< (at 'found acc) 0)
                    { "cum": (+ cum n), "found": (if (< r (+ cum n)) idx -1) }
                    acc)))
            { "cum": 0, "found": -1 }
            (enumerate 0 (- KIND-COUNT 1)))))

  (defun adjust:[integer] (counts:[integer] k:integer by:integer)
    (map (lambda (i:integer) (if (= i k) (+ (at i counts) by) (at i counts)))
         (enumerate 0 (- KIND-COUNT 1))))

  ; One draw: the seed and the card's position pick an index into the remaining
  ; cards; the kind is removed from the pool.
  (defun draw:object (st:object i:integer)
    (let* ((counts (at 'counts st))
           (remaining (at 'remaining st))
           (r (mod (str-to-int 64 (hash (format "{}|{}" [(at 'seed st) i]))) remaining))
           (k (kind-at counts r)))
      { "seed": (at 'seed st), "counts": (adjust counts k -1), "remaining": (- remaining 1)
      , "kinds": (+ (at 'kinds st) [k]) }))

  (defun draw-cards:object (counts:[integer] remaining:integer seed:integer)
    @doc "Draw CARDS-PER-COUP cards from the pool by the seed. Returns the kinds, their names and the pool after."
    (enforce (>= remaining CARDS-PER-COUP) "the pool cannot deal a coup")
    (let ((st (fold (draw) { "seed": seed, "counts": counts, "remaining": remaining, "kinds": [] }
                    (enumerate 0 (- CARDS-PER-COUP 1)))))
      { "kinds": (at 'kinds st)
      , "cards": (map (lambda (k:integer) (at k KINDS)) (at 'kinds st))
      , "counts": (at 'counts st)
      , "remaining": (at 'remaining st) }))

  ; The banker's third-card rule against the player's third card.
  (defun banker-draws:bool (bt:integer p3:integer)
    (cond ((<= bt 2) true)
          ((= bt 3) (!= p3 8))
          ((= bt 4) (and (>= p3 2) (<= p3 7)))
          ((= bt 5) (and (>= p3 4) (<= p3 7)))
          ((= bt 6) (and (>= p3 6) (<= p3 7)))
          false))

  (defun finish:object (punto:[string] banco:[string] used:integer)
    (let ((pt (hand-total punto)) (bt (hand-total banco)))
      { "winner": (cond ((= pt bt) TIE) ((> pt bt) PUNTO) BANCO)
      , "punto": punto, "banco": banco, "used": used }))

  (defun coup-from-cards:object (cards:[string])
    @doc "Deal the coup off the front of `cards` by the Punto Banco tableau. Returns the winner, both hands and how many cards were used."
    (enforce (>= (length cards) CARDS-PER-COUP) "a coup needs six cards to draw from")
    (let* ((p2 [(at 0 cards) (at 2 cards)])
           (b2 [(at 1 cards) (at 3 cards)])
           (pt (hand-total p2))
           (bt (hand-total b2)))
      (if (or (>= pt 8) (>= bt 8))
          ; a natural: the coup ends on two cards each
          (finish p2 b2 4)
          (if (<= pt 5)
              ; the player draws; the banker follows the tableau against that card
              (let* ((p3 (at 4 cards))
                     (punto (+ p2 [p3])))
                (if (banker-draws bt (card-value p3))
                    (finish punto (+ b2 [(at 5 cards)]) 6)
                    (finish punto b2 5)))
              ; the player stands; the banker plays the player's rule
              (if (<= bt 5)
                  (finish p2 (+ b2 [(at 4 cards)]) 5)
                  (finish p2 b2 4))))))

  ; Put the cards a coup did not use back in the pool.
  (defun restore:[integer] (counts:[integer] kinds:[integer])
    (fold (lambda (c:[integer] k:integer) (adjust c k 1)) counts kinds))

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ADMIN / SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (defun house-account:string () HOUSE_ACCOUNT)

  (defun initialize:string (revenue:string target-float:decimal)
    @doc "Admin, once: create the pot, the fresh shoe and record where revenue goes. `revenue` must be an existing principal account an external signer can spend."
    (with-capability (ADMIN)
      (validate-account revenue)
      ; A principal, so a stranger cannot pre-create a plain name and be paid every
      ; fee forever; never this module's own pot; and never a c: or p: principal,
      ; which no external signer can ever spend from and a frozen module cannot
      ; reach -- there is no setter and initialize runs once.
      (enforce (is-principal revenue)
        "revenue must be a principal account (k:, m:, r:, w: or u:), not a claimable name")
      (enforce (!= revenue HOUSE_ACCOUNT) "revenue must not be this module's own pot")
      (enforce (and (!= "c:" (take 2 revenue)) (!= "p:" (take 2 revenue)))
        "revenue must be an account an external signer can spend: not a c: or p: principal")
      ; `try`, because get-balance ABORTS on a missing account
      (let ((bal (try -1.0 (get-balance revenue))))
        (enforce (>= bal 0.0) "the revenue account must already exist"))
      (enforce (> target-float 0.0) "target float must be positive")
      (enforce-unit target-float)
      ; the game row goes in FIRST, so a second initialize fails on it plainly
      (insert game-table GAME-KEY
        { "last-beacon": 0, "round-seq": 0, "current": 0, "reserved": 0.0
        , "revenue": revenue
        , "reserve-fraction": LAUNCH-RESERVE-FRACTION
        , "target-float": target-float
        , "bet-window": LAUNCH-BET-WINDOW
        , "min-bet": LAUNCH-MIN-BET
        , "drand-margin": LAUNCH-DRAND-MARGIN
        , "commission": LAUNCH-COMMISSION
        , "cut-card": LAUNCH-CUT })
      (insert shoe-table SHOE-KEY
        { "counts": FULL-SHOE, "remaining": SHOE-SIZE, "shoe-no": 1, "dealt-since": 0, "shoe-seq": 0 })
      ; The pot's principal can be built from transaction data by anyone, so a
      ; stranger may create the coin row first. Tolerating that is safe: coin
      ; refuses the name to any other guard, so a squatted row IS our account.
      (if (< (try -1.0 (get-balance HOUSE_ACCOUNT)) 0.0)
          (create-account HOUSE_ACCOUNT (pot-guard))
          "the pot account already exists")
      (emit-event (INITIALIZED revenue)))
    "baccarat initialized")

  (defun fund-house:string (funder:string amount:decimal)
    @doc "Add capital to the pot. Permissionless, and it grants no claim on the pot."
    ; a module-specific message: coin's own "transfer amount must be positive"
    ; contains "amount must be positive", so a shared wording would let this check
    ; be deleted with every test still green
    (enforce (> amount 0.0) "fund amount must be positive")
    (transfer funder HOUSE_ACCOUNT amount)
    (emit-event (HOUSE-FUNDED funder amount))
    "house funded")

  (defun withdraw-house:string (amount:decimal)
    @doc "Admin: move UNRESERVED pot funds to the revenue account fixed at initialize. Until the freeze, the admin keyset is also module admin and can reach the pot by other means."
    (enforce (> amount 0.0) "withdrawal amount must be positive")
    (enforce-unit amount)
    (with-capability (ADMIN)
      (let* ((bal (get-balance HOUSE_ACCOUNT))
             (g (read game-table GAME-KEY))
             (reserved (at 'reserved g))
             (to (at 'revenue g))
             (available (- bal reserved)))
        (enforce (<= amount available)
          (format "withdrawal {} exceeds unreserved balance {}" [amount available]))
        (install-capability (coin.TRANSFER HOUSE_ACCOUNT to amount))
        (transfer HOUSE_ACCOUNT to amount)
        (emit-event (HOUSE-WITHDRAWN to amount))))
    "house withdrawal complete")

  (defun set-params:string (reserve-fraction:decimal min-bet:decimal target-float:decimal
                            bet-window:decimal drand-margin:decimal commission:decimal
                            cut-card:integer)
    @doc "Admin: the dials for FUTURE rounds. A live round keeps the share, the minimum, the commission, the cut, its window and its beacon; only the fee ramp reads the target now."
    (enforce (and (> reserve-fraction 0.0) (<= reserve-fraction MAX-RESERVE-FRACTION))
      (format "reserve-fraction must be in (0, {}]" [MAX-RESERVE-FRACTION]))
    (enforce (>= min-bet MIN-BET-FLOOR) (format "min-bet below the floor {}" [MIN-BET-FLOOR]))
    (enforce-unit min-bet)
    (enforce (> target-float 0.0) "target float must be positive")
    (enforce-unit target-float)
    (enforce (and (>= bet-window MIN-BET-WINDOW) (<= bet-window MAX-BET-WINDOW))
      (format "bet-window must be in [{}, {}]" [MIN-BET-WINDOW MAX-BET-WINDOW]))
    (enforce (and (>= drand-margin MIN-DRAND-MARGIN) (<= drand-margin MAX-DRAND-MARGIN))
      (format "drand-margin must be in [{}, {}]" [MIN-DRAND-MARGIN MAX-DRAND-MARGIN]))
    (enforce (and (>= commission MIN-COMMISSION) (<= commission MAX-COMMISSION))
      (format "commission must be in [{}, {}]" [MIN-COMMISSION MAX-COMMISSION]))
    (enforce-prec commission "commission")
    (enforce (and (>= cut-card MIN-CUT) (<= cut-card MAX-CUT))
      (format "cut-card must be in [{}, {}]" [MIN-CUT MAX-CUT]))
    (with-capability (ADMIN)
      (update game-table GAME-KEY
        { "reserve-fraction": reserve-fraction, "min-bet": min-bet
        , "target-float": target-float, "bet-window": bet-window
        , "drand-margin": drand-margin, "commission": commission, "cut-card": cut-card })
      (emit-event (PARAMS-SET reserve-fraction min-bet target-float bet-window drand-margin commission cut-card)))
    "params set")

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; BET ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (defun bet:string (account:string w:object{wager})
    @doc "Place a board. THE ONLY TRANSACTION A PLAYER SIGNS: sign coin.TRANSFER of the total. If you win, claim; if you lose, do nothing."
    (validate-account account)
    ; Coin can pay any existing account, so this is not about payment. What it
    ; refuses is exactly an `m:` principal -- this pot's own account is one -- so
    ; the pot can never be a player at its own table; a module holding a plain
    ; named account is not caught, and widening this would be a new rule.
    (enforce (!= "m:" (take 2 account))
      "an m: principal cannot bet: the pot's own account is one")
      (with-read game-table GAME-KEY
        { "current" := cur, "reserved" := reserved
        , "target-float" := target, "min-bet" := min-bet, "commission" := live-c }
        (let* ((t (curr-time))
               (p (at 'punto w)) (b (at 'banco w)) (tie (at 'tie w))
               (stake (validate-wager w))
               (bal (get-balance HOUSE_ACCOUNT))
               (available (- bal reserved))
               (scale (fee-scale available target)))
          ; keep the open round if it is still taking bets, else start one. The
          ; minimum and the commission are the ROUND's, so a change binds the next
          ; round only. Key "0" never exists, so before the first round the live
          ; values apply.
          (with-default-read rounds (rkey cur)
            { "state": "none", "close-time": t, "min-bet-at-open": min-bet, "commission-at-open": live-c }
            { "state" := cst, "close-time" := cclose, "min-bet-at-open" := cmb, "commission-at-open" := cc }
          (let* ((keep (and (= "open" cst) (<= t cclose)))
                 (mb (if keep cmb min-bet))
                 (c (if keep cc live-c))
                 (fee (fee-for p b tie c scale))
                 (own (board-vector p b tie c)))
            (enforce (>= stake mb) "total bet below the table minimum")
            ; The commission is part of what the player signs. A board that opens a
            ; round takes the live commission, which the house could raise between
            ; the page and the block; the board's own ceiling makes that a refusal
            ; instead of a smaller Banker win.
            (enforce (<= c (at 'commission w))
              (format "the Banker commission is {}, above the {} this board accepts: sign again"
                      [c (at 'commission w)]))
          ; The round is opened HERE, inline, with no separate export.
          ; Every term is read from the game row, never taken from the caller, and
          ; nothing outside `bet` can reach this write.
          (let ((seq (if keep cur
                       (with-read game-table GAME-KEY
                         { "reserved" := oreserved, "round-seq" := prev-seq, "drand-margin" := omargin
                         , "bet-window" := owindow, "reserve-fraction" := ofrac, "min-bet" := omin
                         , "commission" := ocomm, "cut-card" := ocut }
                         (let* ((nseq (+ 1 prev-seq))
                                (oavail (- (get-balance HOUSE_ACCOUNT) oreserved))
                                (nclose (add-time (curr-time) owindow))
                                (ndr (round-at (add-time nclose omargin))))
                           (insert rounds (rkey nseq)
                             { "avail-at-open": oavail, "frac-at-open": ofrac, "min-bet-at-open": omin
                             , "commission-at-open": ocomm, "cut-at-open": ocut
                             , "close-time": nclose, "drand-round": ndr
                             , "exposure": (make-list 3 0.0)
                             , "stake": 0.0, "fee-owed": 0.0, "reserve": 0.0
                             , "state": "open", "winner": "", "punto": [], "banco": [], "liability": 0.0 })
                           (update game-table GAME-KEY { "round-seq": nseq, "current": nseq })
                           (emit-event (ROUND-OPENED nseq nclose ndr))
                           nseq)))))
            ; one board per account per round: a second write would clobber the
            ; first while the round's exposure still counted both
            (with-default-read boards (bkey seq account) { "stake": -1.0 } { "stake" := prior }
              (enforce (< prior 0.0)
                "you already have a board in this round: place every chip in one transaction"))
            (with-read rounds (rkey seq)
              { "exposure" := ex, "stake" := rstake, "fee-owed" := rfee, "reserve" := rres
              , "avail-at-open" := a0, "frac-at-open" := f0 }
              (let* ((new-ex (zip (lambda (x:decimal y:decimal) (+ x y)) ex own))
                     (new-stake (+ rstake stake))
                     (new-fee (+ rfee fee))
                     ; the reserve must dominate BOTH outcomes: paying the best
                     ; slot, and refunding every stake on a void. With this payout
                     ; table the Tie slot (9t + p + b) never falls below the stake
                     ; (p + b + t), so the stake term cannot bind; it is kept as the
                     ; invariant's own statement, at the cost of one comparison.
                     (new-res (+ (vmax [(vmax new-ex) new-stake]) new-fee))
                     ; the table limit bounds the ROUND, against the smaller of the
                     ; pot at open and the pot now, at the share frozen at open
                     (cap (* f0 (if (< available a0) available a0))))
                (enforce (<= (+ (vmax new-ex) new-fee) cap)
                  (format "this round's exposure {} would exceed the table limit {}"
                          [(+ (vmax new-ex) new-fee) cap]))
                ; and what this bet adds must be covered by the pot's OWN spare
                ; capital, not by the stake arriving with it. Unreachable with this
                ; payout table: the reserve is max(exposure) + fee, the table limit
                ; already bounds that by the cap, and the cap never exceeds
                ; `available`. Kept for the same reason as the stake term above.
                (enforce (<= (- new-res rres) available)
                  "the pot cannot cover this bet")
                (update rounds (rkey seq)
                  { "exposure": new-ex, "stake": new-stake
                  , "fee-owed": new-fee, "reserve": new-res })
                (update game-table GAME-KEY
                  { "reserved": (+ reserved (- new-res rres)) })
                (transfer account HOUSE_ACCOUNT stake)
                (insert boards (bkey seq account)
                  { "seq": seq, "account": account, "punto": p, "banco": b, "tie": tie
                  , "stake": stake, "claimed": false })
                (emit-event (BET-PLACED account seq stake (- new-res rres)))
                (format "bet placed in round {}" [seq])))))))))

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RESOLVE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (defun resolve:string (seq:integer sig-hex:string)
    @doc "Deal this round's coup from the drand beacon. PERMISSIONLESS: a forged beacon cannot verify, and coups are dealt in round order."
      (with-read rounds (rkey seq)
        { "state" := st, "drand-round" := dr, "exposure" := ex
        , "fee-owed" := fee, "reserve" := res, "cut-at-open" := cut }
        (enforce (= "open" st) "this round is already settled")
        (with-read shoe-table SHOE-KEY
          { "counts" := counts0, "remaining" := rem0, "shoe-no" := shoe0
          , "dealt-since" := dealt0, "shoe-seq" := last }
          (enforce (= seq (+ last 1)) "coups are dealt in round order: settle the earlier round first")
          ; No time check is needed: a beacon that is not yet published does not
          ; exist, so verified-seed cannot succeed early.
          (let* ((seed (verified-seed (format "baccarat|{}" [seq]) dr sig-hex))
                 ; refill BEFORE the coup when the pool is at or under the cut
                 (refill (<= rem0 cut))
                 (counts1 (if refill FULL-SHOE counts0))
                 (rem1 (if refill SHOE-SIZE rem0))
                 (shoe-no (if refill (+ shoe0 1) shoe0))
                 (six (draw-cards counts1 rem1 seed))
                 (c (coup-from-cards (at 'cards six)))
                 (used (at 'used c))
                 (winner (at 'winner c))
                 (counts2 (restore (at 'counts six) (drop used (at 'kinds six))))
                 (liab (at (slot winner) ex)))
            (if refill (emit-event (SHOE-SHUFFLED seq shoe-no)) "same shoe")
            (update shoe-table SHOE-KEY
              { "counts": counts2, "remaining": (- rem1 used), "shoe-no": shoe-no
              , "dealt-since": (if refill 1 (+ dealt0 1)), "shoe-seq": seq })
            ; fee-owed is zeroed because it is PAID below
            (update rounds (rkey seq)
              { "state": "resolved", "winner": winner, "punto": (at 'punto c), "banco": (at 'banco c)
              , "liability": liab, "fee-owed": 0.0 })
            (with-read game-table GAME-KEY
              { "reserved" := reserved, "revenue" := rev, "last-beacon" := lb }
              ; a verified beacon is PROOF drand was alive at that round
              (update game-table GAME-KEY
                { "reserved": (- reserved (- res liab))
                , "last-beacon": (if (> dr lb) dr lb) })
              (if (> fee 0.0)
                  (let ((dest rev))
                    (install-capability (coin.TRANSFER HOUSE_ACCOUNT dest fee))
                    (transfer HOUSE_ACCOUNT dest fee)
                    (emit-event (FEE-PAID seq fee dest))
                    "fee paid")
                  "no fee"))
            (emit-event (COUP-RESULT seq winner dr (at 'punto c) (at 'banco c)))
            winner))))

  (defun prove-liveness:integer (rnd:integer sig-hex:string)
    @doc "Permissionless: verify a drand beacon and record that drand was alive at that round. One call blocks a premature refund on every pending round at or below it."
    ; Without this, "drand went away" would be indistinguishable from "nobody
    ; settled this round", and the second is a losing player's own choice.
      (let ((seed (verified-seed "liveness" rnd sig-hex)))
        (enforce (!= seed 0) "beacon did not verify")
        (with-read game-table GAME-KEY { "last-beacon" := lb }
          (enforce (> rnd lb) "a later beacon is already on record")
          (update game-table GAME-KEY { "last-beacon": rnd })
          (emit-event (LIVENESS-PROVEN rnd))
          rnd)))

  (defun void-round:string (seq:integer)
    @doc "Refund a round whose beacon can never arrive. Permissionless; needs ninety days AND no beacon verified at or after the round's own."
    (with-read rounds (rkey seq)
      { "state" := st, "drand-round" := dr, "reserve" := res, "stake" := stk }
      (enforce (= "open" st) "this round is not open")
      (enforce (> (diff-time (curr-time) (time-of-round dr)) VOID-AFTER)
        "the beacon can still be submitted")
      ; if this module has verified a beacon at or after this round's, drand was
      ; alive by then and the round must be resolved, not refunded
      (with-read game-table GAME-KEY { "last-beacon" := lb }
        (enforce (< lb dr)
          "drand has been seen since this round: resolve it, do not refund it"))
      ; a void takes the round's turn in the shoe order without dealing
      (with-read shoe-table SHOE-KEY { "shoe-seq" := last }
        (enforce (= seq (+ last 1)) "rounds are settled in order: settle the earlier round first")
        (update shoe-table SHOE-KEY { "shoe-seq": seq }))
      ; no fee is taken on a void, so the accrual is dropped, not paid
      (update rounds (rkey seq) { "state": "void", "liability": stk, "fee-owed": 0.0 })
      (with-read game-table GAME-KEY { "reserved" := reserved }
        (update game-table GAME-KEY { "reserved": (- reserved (- res stk)) }))
      (emit-event (ROUND-VOID seq stk)))
    "round void: every stake is refundable")

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CLAIM ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (defun claim:string (seq:integer account:string)
    @doc "Collect a win, or a refund from a void round. PERMISSIONLESS: it always pays the account that placed the board."
      (with-read boards (bkey seq account)
        { "punto" := p, "banco" := b, "tie" := t, "stake" := stk, "claimed" := done }
        (enforce (not done) "this board has already been claimed")
        (with-read rounds (rkey seq)
          { "state" := st, "winner" := winner, "liability" := liab, "commission-at-open" := c }
          (let ((amount (cond ((= st "resolved") (board-payout p b t c winner))
                              ((= st "void") stk)
                              (enforce false "this round has not been settled yet"))))
            (enforce (> amount 0.0) "nothing to claim: this board did not win")
            (update boards (bkey seq account) { "claimed": true })
            (update rounds (rkey seq) { "liability": (- liab amount) })
            (with-read game-table GAME-KEY { "reserved" := reserved }
              (update game-table GAME-KEY { "reserved": (- reserved amount) }))
            (install-capability (coin.TRANSFER HOUSE_ACCOUNT account amount))
            (transfer HOUSE_ACCOUNT account amount)
            (emit-event (CLAIMED account seq amount))
            (format "paid {}" [amount])))))

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; VIEWS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (defun get-round:object (seq:integer) (read rounds (rkey seq)))
  (defun get-board:object (seq:integer account:string) (read boards (bkey seq account)))
  (defun get-params:object () (read game-table GAME-KEY))

  (defun shoe-status:object ()
    @doc "The pool as of the last dealt coup: every kind's count, the cards remaining, the decks, and which round the shoe stands after."
    (+ (read shoe-table SHOE-KEY) { "decks": DECKS, "kinds": KINDS, "shoe-size": SHOE-SIZE }))

  ; The boards of one round, for whoever pays winners. A full scan: for /local
  ; use, never inside a transaction.
  (defun round-boards:[object{board}] (seq:integer)
    (select boards (where 'seq (= seq))))

  ; The largest stake on one box that `bet` would accept: the table limit binds
  ; EVERY slot -- after the board, slot j must hold ex[j] + v[j]*s + fee-owed +
  ; f*s <= cap, where v is the box's payout per unit on each slot (a Banker unit
  ; is 1.95 on the Banker slot and 1 on the Tie slot, where its stake is pushed)
  ; and f the fee per unit -- so the maximum is the smallest of the three slot
  ; bounds, floored to coin precision. Never above what `bet` takes, and within
  ; two units of the last decimal on Banker (two floors: the payout and the fee)
  ; and one on Player and Tie. It is the smallest of the slot bounds; a slot the
  ; box does not load still bounds it once that slot's room is gone.
  (defun box-max:decimal (cap:decimal fee-owed:decimal ex:[decimal] v:[decimal] f:decimal)
    (fold (lambda (m:decimal j:integer)
            (let ((d (+ (at j v) f))
                  (room (- cap (+ fee-owed (at j ex)))))
              (if (> d 0.0)
                  (let ((s (floor (/ (if (> room 0.0) room 0.0) d) PREC)))
                    (if (< s m) s m))
                  ; a slot this box does not load still bounds it: with no room
                  ; left there `bet` refuses every board on the box, so nothing fits
                  (if (< room 0.0) 0.0 m))))
          1000000000000.0
          (enumerate 0 2)))

  (defun pot-status:object ()
    @doc "Solvency at a glance; on each box the largest board `bet` would ACCEPT right now, never above and within two units of the last decimal on Banker and one on Player and Tie (max-*-bet: the open round's headroom, or the share of the spare pot a fresh round may risk), and what the pot is SIZED TO KEEP through a year of play (sized-*-bet: one BANKROLL-DIVISOR-th of its spare capital; the Tie box's share of that). Under the minimum, 0.0."
    (let* ((bal (get-balance HOUSE_ACCOUNT))
           (g (read game-table GAME-KEY))
           (reserved (at 'reserved g))
           (available (- bal reserved))
           (scale (fee-scale available (at 'target-float g)))
           (cur (at 'current g))
           (open (if (= cur 0) false
                     (let ((r (read rounds (rkey cur))))
                       (and (= "open" (at 'state r)) (<= (curr-time) (at 'close-time r))))))
           ; the cap binds on the OPEN round, against the smaller of the pot at open
           ; and the pot now -- the same expression `bet` measures against; with no
           ; round open, a fresh round's cap, with nothing yet on any slot
           (cap (if open
                    (let* ((r (read rounds (rkey cur))) (a0 (at 'avail-at-open r)))
                      (* (at 'frac-at-open r) (if (< available a0) available a0)))
                    (* (at 'reserve-fraction g) available)))
           (ex (if open (at 'exposure (read rounds (rkey cur))) (make-list 3 0.0)))
           (fo (if open (at 'fee-owed (read rounds (rkey cur))) 0.0))
           (mb (if open (at 'min-bet-at-open (read rounds (rkey cur))) (at 'min-bet g)))
           (c (if open (at 'commission-at-open (read rounds (rkey cur))) (at 'commission g)))
           (by-bankroll (floor (/ available BANKROLL-DIVISOR) PREC))
           (by-bankroll-tie (floor (/ (* 2.0 by-bankroll) (+ TIE-PAYS 1.0)) PREC))
           ; a figure under the minimum is not a board, so it is published as 0.0
           (advert (lambda (a:decimal) (if (>= a mb) a 0.0))))
      { "balance": bal, "reserved": reserved, "available": available
      , "fee-scale-now": scale, "commission": c, "min-bet": mb
      ; "up to X today": what `bet` accepts on each box now, never above, within two 1e-12 units on Banker and one elsewhere
      , "max-punto-bet": (advert (box-max cap fo ex [2.0 0.0 1.0] (* scale PUNTO-EDGE)))
      , "max-banco-bet": (advert (box-max cap fo ex [0.0 (- 2.0 c) 1.0] (* scale (banco-edge c))))
      , "max-tie-bet":   (advert (box-max cap fo ex [0.0 0.0 (+ TIE-PAYS 1.0)] (* scale TIE-EDGE)))
      ; "sized to keep Y": the bankroll rule, shown beside the maximum, never enforced by `bet`
      , "sized-punto-bet": (advert by-bankroll)
      , "sized-banco-bet": (advert by-bankroll)
      , "sized-tie-bet":   (advert by-bankroll-tie) }))
)

(create-table game-table)
(create-table shoe-table)
(create-table rounds)
(create-table boards)
