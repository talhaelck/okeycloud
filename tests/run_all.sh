#!/bin/bash
# The whole headless test suite, one verdict line per test (all green: exit=0 and FAILS: 0 / PASS on every line).
# Takes several minutes. Run from anywhere:  bash tests/run_all.sh
# Godot is taken from $GODOT, else C:\Tools\Godot\godot.cmd, else `godot` on the PATH.
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/c/Tools/Godot/godot.cmd}
[ -x "$GODOT" ] || GODOT=godot

run() {
  local name=$1; shift
  local out
  out=$(timeout 900 "$GODOT" --path . --headless "$@" 2>&1)
  local code=$?
  local verdict
  verdict=$(echo "$out" | grep -E "^FAILS:|PASS|HANDS_CLEAR|^FAIL |^  FAIL" | tail -4 | tr '\n' ' ')
  local errs
  errs=$(echo "$out" | grep -c "SCRIPT ERROR")
  echo "[$name] exit=$code script_errors=$errs $verdict"
}

run rules_test --script res://tests/rules_test.gd
run tiles_test --script res://tests/tiles_test.gd
run drag_test --script res://tests/drag_test.gd
run physics_test --script res://tests/physics_test.gd
run floating_props --script res://tests/floating_props_test.gd
run sfx_test --fixed-fps 30 --script res://tests/sfx_test.gd
run ui_test --fixed-fps 30 --script res://tests/ui_test.gd
run presentation --fixed-fps 30 --script res://tests/presentation_test.gd
run player_moves --fixed-fps 30 --script res://tests/player_moves_test.gd
run quick_moves --fixed-fps 30 --script res://tests/quick_moves_test.gd
run stealing --fixed-fps 30 --script res://tests/stealing_test.gd
run hand_end --fixed-fps 30 --script res://tests/hand_end_test.gd
run dayi_hands --fixed-fps 30 --script res://tests/dayi_hands_test.gd
run hands_smooth --fixed-fps 30 --script res://tests/hands_smooth_test.gd
run hands_clear --fixed-fps 30 --script res://tests/hands_clear_test.gd
run live_hands --fixed-fps 30 --script res://tests/live_hands_audit.gd -- --frames=2400
run flow --fixed-fps 30 --script res://tests/game_flow_test.gd -- --set=turn_time_limit=1 --hands=2
run flow_stealing --fixed-fps 30 --script res://tests/game_flow_test.gd -- --set=turn_time_limit=1 --stealing --hands=3
echo "ALL DONE"
