#!/usr/bin/env bash
set -u
selection=""
dry_run=0
no_config=0
install_root="$HOME/.creative-mcps"
platform="$(uname -s)"
for argument in "$@"; do
  case "$argument" in
    --selection=*) selection="$(printf '%s' "$argument" | sed 's/^--selection=//')" ;;
    --dry-run) dry_run=1 ;;
    --no-config) no_config=1 ;;
    *) echo "Unknown option: $argument" >&2; exit 2 ;;
  esac
done
title() { printf '\n=== %s ===\n' "$1"; }
note() { printf '  %s\n' "$1"; }
warning() { printf '  Warning: %s\n' "$1" >&2; }
require_command() { [ "$dry_run" -eq 1 ] || command -v "$1" >/dev/null 2>&1 || { echo "'$1' is required to $2." >&2; exit 1; }; }
run() { local label="$1"; shift; if [ "$dry_run" -eq 1 ]; then note "Dry run: would $label"; else note "$label"; "$@"; fi; }
add_codex() { local name="$1"; shift; [ "$no_config" -eq 1 ] && { note "Skipping Codex configuration for $name."; return; }; require_command codex 'configure MCP servers in Codex'; [ "$dry_run" -eq 1 ] && { note "Dry run: would add $name to Codex."; return; }; codex mcp get "$name" >/dev/null 2>&1 || { codex mcp add "$name" -- "$@"; note "Added $name to Codex."; }; }
add_codex_http() { local name="$1" url="$2"; [ "$no_config" -eq 1 ] && { note "Skipping Codex configuration for $name."; return; }; require_command codex 'configure MCP servers in Codex'; [ "$dry_run" -eq 1 ] && { note "Dry run: would add $name to Codex."; return; }; codex mcp get "$name" >/dev/null 2>&1 || { codex mcp add "$name" --url "$url"; note "Added $name to Codex."; }; }
install_godot() { title 'Godot MCP'; require_command npm 'install Godot MCP'; run 'install Godot MCP' npm install -g '@coding-solo/godot-mcp@0.1.1'; add_codex godot godot-mcp; note 'Set GODOT_PATH in Codex MCP settings if automatic detection fails.'; }
install_blender() { title 'Blender MCP'; require_command python3 'install Blender MCP'; require_command git 'install Blender MCP'; local environment="$install_root/blender-mcp"; [ -x "$environment/bin/python" ] || run 'create Blender MCP private environment' python3 -m venv "$environment"; run 'install Blender MCP from Blender Lab' "$environment/bin/python" -m pip install 'git+https://projects.blender.org/lab/blender_mcp.git#subdirectory=mcp'; add_codex blender "$environment/bin/python" -m blmcp; note 'In Blender: Preferences > Get Extensions > add https://lab.blender.org/ > install and enable MCP. Then start its local bridge.'; }
install_after_effects() { title 'After Effects MCP'; warning 'This supplied integration currently supports Windows only. Use Install on Windows.bat.'; }
install_premiere() { title 'Premiere Pro MCP'; [ "$platform" = Linux ] && { warning 'Adobe Premiere Pro is not supported on Linux.'; return; }; require_command npm 'install Premiere Pro MCP'; run 'install Premiere Pro MCP' npm install -g 'premiere-pro-mcp@1.6.0'; run 'install the Premiere bridge panel' premiere-pro-mcp --install-cep; add_codex premiere-pro premiere-pro-mcp; note 'Restart Premiere Pro, then confirm Window > Extensions > MCP Bridge shows Running.'; }
install_unreal() { title 'Unreal Engine MCP'; add_codex_http unreal-engine 'http://127.0.0.1:8000/mcp'; note 'In Unreal Engine 5.8 enable Unreal MCP, Python Editor Script Plugin, and EditorToolset; then start the local MCP server on port 8000.'; }
if [ -z "$selection" ]; then read -r -p 'Choose all, godot, blender, after-effects, premiere-pro, or unreal-engine (Enter for all): ' selection; fi
if [ -z "$selection" ]; then selection=all; fi
case "$selection" in
  all) install_godot; install_blender; install_after_effects; install_premiere; install_unreal ;;
  godot) install_godot ;; blender) install_blender ;; after-effects) install_after_effects ;; premiere-pro) install_premiere ;; unreal-engine) install_unreal ;;
  *) echo "Unknown choice: $selection" >&2; exit 2 ;;
esac
printf '\nFinished. Restart Codex after installation, then open the relevant creative app before using its tools.\n'
