#!/usr/bin/env bash
# Smoke check — présence des modules clés Blade Concord (pas d'exécution Studio).
# Usage: ./tools/smoke-check.sh
# Exit 0 = OK ; 1 = module(s) manquant(s)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
MISSING=()

check() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    PASS=$((PASS + 1))
    printf "  OK  %s\n" "$label"
  else
    FAIL=$((FAIL + 1))
    MISSING+=("$label → $path")
    printf "  MISSING  %s (%s)\n" "$label" "$path"
  fi
}

echo "== Blade Concord — smoke-check modules =="
echo "Root: $ROOT"
echo

echo "-- Showcase / Combat anim --"
check "AnimationShowcase" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Combat/AnimationShowcase.lua"
check "CombatAnimator" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Combat/CombatAnimator.lua"
check "SaberPose" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Combat/SaberPose.lua"
check "AnimDebugOverlay" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Combat/AnimDebugOverlay.lua"

echo "-- Server combat / meta --"
check "FormService" "src/ServerScriptService/BladeConcord/Meta/FormService.lua"
check "CombatService" "src/ServerScriptService/BladeConcord/Combat/CombatService.lua"
check "MatchService" "src/ServerScriptService/BladeConcord/Match/MatchService.lua"
check "BotStub" "src/ServerScriptService/BladeConcord/Combat/BotStub.lua"
check "ArenaService" "src/ServerScriptService/BladeConcord/Combat/ArenaService.lua"
check "ShopService" "src/ServerScriptService/BladeConcord/Meta/ShopService.lua"
check "RankedService" "src/ServerScriptService/BladeConcord/Meta/RankedService.lua"

echo "-- Shared / visual / FX --"
check "CombatConfig" "src/ReplicatedStorage/BladeConcord/Shared/CombatConfig.lua"
check "SaberBuilder" "src/ReplicatedStorage/BladeConcord/Visual/SaberBuilder.lua"
check "AnimationSets" "src/ReplicatedStorage/BladeConcord/Animation/AnimationSets.lua"
check "ProceduralPlayer" "src/ReplicatedStorage/BladeConcord/Animation/ProceduralPlayer.lua"
check "CombatFx" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/FX/CombatFx.lua"
check "CombatHud" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Combat/CombatHud.lua"
check "MetaHud" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/UI/MetaHud.lua"
check "TutorialTips" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/UI/TutorialTips.lua"
check "SoundHooks" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Audio/SoundHooks.lua"

echo "-- Project / tools --"
check "default.project.json" "default.project.json"
check "CombatBootstrap.client" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Combat/CombatBootstrap.client.lua"
check "CombatBootstrap.server" "src/ServerScriptService/BladeConcord/Combat/CombatBootstrap.server.lua"

echo
echo "Result: $PASS ok · $FAIL missing"

if [[ "$FAIL" -gt 0 ]]; then
  echo "Missing modules:"
  for m in "${MISSING[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

echo "Smoke check PASS"
exit 0
