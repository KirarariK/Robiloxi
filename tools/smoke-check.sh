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
check "SlotMatchService" "src/ServerScriptService/BladeConcord/Match/SlotMatchService.lua"
check "DoubleJumpService" "src/ServerScriptService/BladeConcord/Combat/DoubleJumpService.lua"
check "FocusService" "src/ServerScriptService/BladeConcord/Combat/FocusService.lua"
check "BotStub" "src/ServerScriptService/BladeConcord/Combat/BotStub.lua"
check "ArenaService" "src/ServerScriptService/BladeConcord/Combat/ArenaService.lua"
check "LobbyBuilder" "src/ServerScriptService/BladeConcord/Lobby/LobbyBuilder.lua"
check "LobbyConfig" "src/ServerScriptService/BladeConcord/Lobby/LobbyConfig.lua"
check "LobbyLighting" "src/ServerScriptService/BladeConcord/Lobby/LobbyLighting.lua"
check "LobbyProps" "src/ServerScriptService/BladeConcord/Lobby/LobbyProps.lua"
check "LobbyUtil" "src/ServerScriptService/BladeConcord/Lobby/LobbyUtil.lua"
check "ShopService" "src/ServerScriptService/BladeConcord/Meta/ShopService.lua"
check "RankedService" "src/ServerScriptService/BladeConcord/Meta/RankedService.lua"

echo "-- Shared / visual / FX --"
check "CombatConfig" "src/ReplicatedStorage/BladeConcord/Shared/CombatConfig.lua"
check "SaberBuilder" "src/ReplicatedStorage/BladeConcord/Visual/SaberBuilder.lua"
check "NeonFx" "src/ReplicatedStorage/BladeConcord/Visual/NeonFx.lua"
check "AnimationSets" "src/ReplicatedStorage/BladeConcord/Animation/AnimationSets.lua"
check "ProceduralPlayer" "src/ReplicatedStorage/BladeConcord/Animation/ProceduralPlayer.lua"
check "CombatFx" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/FX/CombatFx.lua"
check "LobbyNeon" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/FX/LobbyNeon.client.lua"
check "CombatHud" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Combat/CombatHud.lua"
check "MetaHud" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/UI/MetaHud.lua"
check "LobbyHud" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/UI/LobbyHud.lua"
check "TutorialTips" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/UI/TutorialTips.lua"
check "UIKit" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/UI/Kit/init.lua"
check "FormsScreen" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/UI/Screens/FormsScreen.lua"
check "MatchEndScreen" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/UI/Screens/MatchEndScreen.lua"
check "Theme" "src/ReplicatedStorage/BladeConcord/Shared/Theme.lua"
check "SoundHooks" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Audio/SoundHooks.lua"

echo "-- Project / tools --"
check "default.project.json" "default.project.json"
check "CombatBootstrap.client" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Combat/CombatBootstrap.client.lua"
check "CombatBootstrap.server" "src/ServerScriptService/BladeConcord/Combat/CombatBootstrap.server.lua"

echo
echo "-- Hardening patterns --"
PATTERN_FAIL=0
pattern_check() {
  local label="$1"
  local file="$2"
  local needle="$3"
  if [[ -f "$file" ]] && grep -q "$needle" "$file"; then
    PASS=$((PASS + 1))
    printf "  OK  %s\n" "$label"
  else
    PATTERN_FAIL=$((PATTERN_FAIL + 1))
    printf "  MISSING  %s (%s)\n" "$label" "$needle"
  fi
}
pattern_check "DataStoreSafe.loadResult" "src/ServerScriptService/BladeConcord/Data/DataStoreSafe.lua" "loadResult"
pattern_check "PlayerData loadFailed" "src/ServerScriptService/BladeConcord/Data/PlayerDataService.lua" "loadFailed"
pattern_check "Match onPlayerRemoving" "src/ServerScriptService/BladeConcord/Match/MatchService.lua" "onPlayerRemoving"
pattern_check "Match rematchIn" "src/ServerScriptService/BladeConcord/Match/MatchService.lua" "rematchIn"
pattern_check "Slot bindDuelSlots" "src/ServerScriptService/BladeConcord/Match/SlotMatchService.lua" "bindDuelSlots"
pattern_check "Slot MaxDuelSlots" "src/ServerScriptService/BladeConcord/Match/SlotMatchService.lua" "MaxDuelSlots"
pattern_check "pickMatchArena" "src/ServerScriptService/BladeConcord/Combat/ArenaService.lua" "pickMatchArena"
pattern_check "BC_MatchArena tag" "src/ReplicatedStorage/BladeConcord/Shared/CombatConfig.lua" "MatchArena"
pattern_check "DoubleJump MobilityIntent" "src/ServerScriptService/BladeConcord/Combat/CombatService.lua" "DoubleJump"
pattern_check "Force Push F" "src/StarterPlayer/StarterPlayerScripts/BladeConcord/Combat/InputCombat.lua" "KeyCode.F"
pattern_check "LobbySpawn prefer" "src/ServerScriptService/BladeConcord/Combat/ArenaService.lua" "LobbySpawn"
pattern_check "toClientSnapshot nil-safe" "src/ServerScriptService/BladeConcord/Data/PlayerDataService.lua" "PlayerProfile?"
pattern_check "NeonStrip tag" "src/ServerScriptService/BladeConcord/Lobby/LobbyConfig.lua" "BC_NeonStrip"
pattern_check "NeonFx bind" "src/ServerScriptService/BladeConcord/Lobby/LobbyBuilder.lua" "bindNeonStrips"

echo
echo "Result: $PASS ok · $FAIL missing · pattern_fail=$PATTERN_FAIL"

if [[ "$FAIL" -gt 0 || "$PATTERN_FAIL" -gt 0 ]]; then
  echo "Missing modules:"
  for m in "${MISSING[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

echo "Smoke check PASS"
exit 0

