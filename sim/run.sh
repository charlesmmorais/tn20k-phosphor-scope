#!/usr/bin/env bash
# ============================================================================
#  run.sh - Roda todos os testbenches com Icarus Verilog / run all testbenches
#  Requer: iverilog + vvp no PATH (sudo apt install iverilog)
#  Requires iverilog + vvp in PATH.
# ============================================================================
set -e
cd "$(dirname "$0")"

# A tabela de seno precisa estar no cwd da simulacao / sine table needed in cwd
cp ../src/sine_lut.hex .

# testbenches rapidos / fast testbenches
FAST="tb_video_timing tb_signal_gen tb_tmds_encoder"
# integracao (um pouco mais lento) / integration (a bit slower)
SLOW="tb_scope_engine"

pass=0; fail=0
run() {
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
    iverilog -g2012 -DSIM -o "/tmp/$1.vvp" -s "$1" ../src/*.v "$1.v"
    out=$(vvp "/tmp/$1.vvp")
    echo "$out" | grep -E "PASS|FAIL|pattern|info|simbolos|OK" || true
    if echo "$out" | grep -q "PASS"; then pass=$((pass+1)); else fail=$((fail+1)); fi
}

for t in $FAST $SLOW; do run "$t"; done

echo
echo "############################################################"
echo "  RESULTADO / RESULT:  $pass PASS, $fail FAIL"
echo "############################################################"

# Dica: o smoke test do topo (tb_top_smoke) tambem existe, mas e bem mais
# lento por causa do clock serial de 126 MHz. Rode manualmente se quiser:
#   iverilog -g2012 -DSIM -o /tmp/s.vvp -s tb_top_smoke ../src/*.v tb_top_smoke.v && vvp /tmp/s.vvp
rm -f sine_lut.hex
exit $fail
