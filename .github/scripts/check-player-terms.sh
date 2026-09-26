#!/usr/bin/env bash
# The player terms state numbers. Those numbers must BE the contract's, not a
# hand-maintained copy that drifts. This reads both and compares. The edges are
# recomputed here from the integer fractions the contract derives them from.
#
# FAILS CLOSED. A constant that cannot be read is an error, never a silent skip — a check that
# inspected nothing must never report clean.
set -uo pipefail
cd "$(dirname "$0")/../.."
DOC=docs/BACCARAT-PLAYER-TERMS.md
SRC=pact/modules/baccarat.pact
BAD=0

konst () { grep -oE "\(defconst $1:[a-z]+ [^)]*\)" "$SRC" | head -1 | grep -oE '[0-9.]+' | head -1; }
want () { # want <label> <expected> <pattern-that-must-appear>
  if grep -qF "$3" "$DOC"; then printf '  OK    %-44s %s\n' "$1" "$2"
  else printf '  BAD   %-44s doc does not say %s\n' "$1" "$3"; BAD=$((BAD+1)); fi
}

MINBET=$(konst LAUNCH-MIN-BET); WINDOW=$(konst LAUNCH-BET-WINDOW); MARGIN=$(konst LAUNCH-DRAND-MARGIN)
MINMARGIN=$(konst MIN-DRAND-MARGIN); VOIDS=$(konst VOID-AFTER)
FRAC=$(konst LAUNCH-RESERVE-FRACTION); MAXFRAC=$(konst MAX-RESERVE-FRACTION)
FLOOR=$(konst MIN-BET-FLOOR); COMM=$(konst LAUNCH-COMMISSION); CUT=$(konst LAUNCH-CUT); MINCUT=$(konst MIN-CUT)
DECKS=$(konst DECKS); TIEPAYS=$(konst TIE-PAYS); DIV=$(konst BANKROLL-DIVISOR)
for v in MINBET WINDOW MARGIN MINMARGIN VOIDS FRAC MAXFRAC FLOOR COMM CUT MINCUT DECKS TIEPAYS DIV; do
  [ -n "${!v}" ] || { echo "  BAD   constant $v could not be read from $SRC"; BAD=$((BAD+1)); }
done
[ "$BAD" = 0 ] || { echo "  terms BAD: $BAD (a constant was unreadable — refusing to report clean)"; exit 1; }
# the three fractions, in the order the contract writes them
read -r NP DP NB DB NT DT < <(grep -oE '\(dec [0-9]+\)' "$SRC" | grep -oE '[0-9]+' | head -6 | tr '\n' ' ')
[ -n "${DT:-}" ] || { echo "  BAD   could not read the six integers of the three fractions from $SRC"; echo "  terms BAD: 1"; exit 1; }
EDGES=$(python3 - "$NP" "$DP" "$NB" "$DB" "$NT" "$DT" "$COMM" "$TIEPAYS" <<'PY'
import sys
from decimal import Decimal, ROUND_HALF_EVEN, ROUND_CEILING, getcontext
getcontext().prec = 60
np_, dp, nb, db, nt, dt, comm, tiepays = sys.argv[1:]
from decimal import ROUND_FLOOR
q = lambda a, b: (Decimal(a) / Decimal(b)).quantize(Decimal('1e-30'), rounding=ROUND_HALF_EVEN)
pp, pb, pt = q(np_, dp), q(nb, db), q(nt, dt)
r12 = lambda x: x.quantize(Decimal('1e-12'), rounding=ROUND_FLOOR)
punto = r12(pb - pp); banco = r12(pp - (1 - Decimal(comm)) * pb); tie = r12(1 - (Decimal(tiepays) + 1) * pt)
minc = (1 - pp / pb).quantize(Decimal('1e-12'), rounding=ROUND_CEILING)
pct = lambda x: f"{(x * 100):.4f}"
print(pct(punto), pct(banco), pct(tie), f"{(pp*100):.4f}", f"{(pb*100):.4f}", f"{(pt*100):.4f}",
      f"{((1-punto)*100):.3f}", f"{((1-banco)*100):.3f}", f"{((1-tie)*100):.3f}", f"{(minc*100):.4f}")
PY
)
read -r EP EB ET PP PB PT RP RB RT MINC <<< "$EDGES"

want "minimum bet"          "$MINBET KDA"     "**$(python3 -c "print('%g' % float('$MINBET'))") KDA** minimum"
grep -qF "**$(python3 -c "print('%g' % float('$FLOOR'))") KDA**" "$DOC" && printf '  OK    %-44s %s\n' "min-bet floor" "$FLOOR" || { printf '  BAD   %-44s doc does not say the floor %s\n' "min-bet floor" "$FLOOR"; BAD=$((BAD+1)); }
want "betting window"       "${WINDOW%.*}s"   "closes ${WINDOW%.*} seconds"
want "drand margin"         "${MARGIN%.*}s"   "**${MARGIN%.*} seconds after betting closes**"
want "drand margin floor"   "${MINMARGIN%.*}s" "below **${MINMARGIN%.*} seconds**"
want "refund grace"         "$(python3 -c "print(int(float('$VOIDS')/86400))") days" "refund after $(python3 -c "print(int(float('$VOIDS')/86400))") days"
want "table limit"          "$(python3 -c "print('%g' % (float('$FRAC')*100))")%" "**$(python3 -c "print('%g' % (float('$FRAC')*100))")%** of the house"
want "table limit ceiling"  "$(python3 -c "print('%g' % (float('$MAXFRAC')*100))")%" "above **$(python3 -c "print('%g' % (float('$MAXFRAC')*100))")%**"
want "commission launch"    "$(python3 -c "print('%g' % (float('$COMM')*100))")%" "launched at **$(python3 -c "print('%g' % (float('$COMM')*100))")%**"
want "commission floor"     "$MINC%"          "below **$MINC%**"
want "cut card launch"      "$CUT"            "When **$CUT cards or fewer**"
want "cut card floor"       "$MINCUT"         "between **$MINCUT** cards"
want "decks"                "$DECKS"          "**$DECKS decks**"
want "tie pays"             "${TIEPAYS%.*}:1" "| Tie | ${TIEPAYS%.*} to 1 |"
want "bankroll divisor"     "1/$DIV"          "one ${DIV%.*}th"
want "player edge"          "$EP%"            "**$EP%**"
want "banker edge"          "$EB%"            "**$EB%**"
want "tie edge"             "$ET%"            "**$ET%**"
want "player return"        "$RP%"            "$RP%"
want "banker return"        "$RB%"            "$RB%"
want "tie return"           "$RT%"            "$RT%"
want "P(player)"            "$PP%"            "Player wins $PP%"
want "P(banker)"            "$PB%"            "Banker $PB%"
want "P(tie)"               "$PT%"            "tie $PT%"

echo "  terms BAD: $BAD"
[ "$BAD" = 0 ]
