#!/usr/bin/env bash
set -Eeuo pipefail

selection=""
dry_run=0
no_config=0
replace_config=0
install_root="$HOME/.creative-mcps"
npm_root="$install_root/npm"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
platform="$(uname -s)"
step='read installer options'
# Finder-launched terminals may not have Homebrew or Codex on PATH yet.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/Applications/Codex.app/Contents/Resources"
trap 'status=$?; printf "\nInstallation stopped: could not %s (exit %s).\nFix the error above and rerun the same command.\n" "$step" "$status" >&2; exit "$status"' ERR

for argument in "$@"; do
  case "$argument" in
    --selection=*) selection="${argument#--selection=}" ;;
    --dry-run) dry_run=1 ;;
    --no-config) no_config=1 ;;
    --replace-config) replace_config=1 ;;
    --help)
      printf 'Usage: bash install-mcps.sh [--selection=all|godot|blender|after-effects|premiere-pro|unreal-engine] [--dry-run] [--no-config] [--replace-config]\n'
      exit 0 ;;
    *) echo "Unknown option: $argument" >&2; exit 2 ;;
  esac
done

title() { printf '\n=== %s ===\n' "$1"; }
note() { printf '  %s\n' "$1"; }
warning() { printf '  Warning: %s\n' "$1" >&2; }
require_command() {
  if [ "$dry_run" -eq 0 ] && ! command -v "$1" >/dev/null 2>&1; then
    printf "'%s' is required to %s. See README.md > Requirements, then reopen the installer.\n" "$1" "$2" >&2
    exit 1
  fi
}
run() {
  step="$1"; shift
  if [ "$dry_run" -eq 1 ]; then
    note "Dry run: would $step"
  else
    note "$step"
    "$@"
  fi
}
configure() {
  local name="$1"; shift
  if [ "$no_config" -eq 1 ]; then
    note "Skipping Codex configuration for $name."
  elif [ "$dry_run" -eq 1 ]; then
    note "Dry run: would configure $name in Codex."
  elif codex mcp get "$name" >/dev/null 2>&1 && [ "$replace_config" -eq 0 ]; then
    note "$name is already configured; its entry was left unchanged."
    note "To repair an entry from an earlier failed install, rerun --selection=$name --replace-config."
  else
    run "configure $name in Codex" codex mcp add "$name" "$@"
  fi
}
node_path() {
  if [ "$dry_run" -eq 1 ]; then printf '/absolute/path/to/node'; else command -v node; fi
}
install_godot() {
  title 'Godot MCP'
  require_command npm 'install Godot MCP'
  require_command node 'run Godot MCP'
  run 'install Godot MCP in your user folder' npm install --prefix "$npm_root" -g '@coding-solo/godot-mcp@0.1.1'
  configure godot -- "$(node_path)" "$npm_root/lib/node_modules/@coding-solo/godot-mcp/build/index.js"
  note 'Godot itself must be installed. Set GODOT_PATH in Codex MCP settings if automatic detection fails.'
}
install_blender() {
  title 'Blender MCP'
  require_command python3 'install Blender MCP'
  require_command git 'install Blender MCP'
  local environment="$install_root/blender-mcp"
  if [ ! -x "$environment/bin/python" ]; then
    run 'create Blender MCP private environment' python3 -m venv "$environment"
  fi
  run 'install Blender MCP from Blender Lab' "$environment/bin/python" -m pip install 'git+https://projects.blender.org/lab/blender_mcp.git#subdirectory=mcp'
  run 'check Blender MCP dependencies' "$environment/bin/python" -m pip check
  configure blender -- "$environment/bin/python" -m blmcp
  note 'In Blender: Preferences > Get Extensions > add https://lab.blender.org/ > install and enable MCP. Then start its local bridge.'
}
install_after_effects() {
  title 'After Effects MCP'
  if [ "$platform" != Darwin ]; then
    warning 'Skipped: After Effects requires macOS or Windows. On Windows use Install on Windows.bat.'
    return 0
  fi
  require_command git 'download After Effects MCP'
  require_command npm 'build After Effects MCP'
  require_command node 'run After Effects MCP'
  local repo="$install_root/after-effects-mcp"
  # Pin the version whose engine is supported by our Mac panel.
  local revision=e38b2609cde262822b888e815684117b35447b11
  run 'check Node.js 20.19 or newer for After Effects' node -e 'const [major, minor] = process.versions.node.split(".").map(Number); if (major < 20 || (major === 20 && minor < 19) || (major === 22 && minor < 12)) { console.error("Use a current Node.js LTS release (20.19+ or 22.12+)."); process.exit(1); }'
  run 'create the private creative MCP folder' mkdir -p "$install_root"
  if [ ! -d "$repo" ]; then
    run 'download After Effects MCP' git clone https://github.com/HeroicSwan/after-effects-mcp.git "$repo"
    run 'select the supported After Effects version' git -C "$repo" checkout --detach "$revision"
  elif [ "$dry_run" -eq 0 ]; then
    if [ "$(git -C "$repo" rev-parse HEAD)" != "$revision" ] || [ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]; then
      echo "Existing After Effects source differs from the supported revision. Left untouched: $repo" >&2
      exit 1
    fi
  fi
  # This upstream revision ships a lockfile that disagrees with package.json.
  # Ignore that lockfile without modifying the independent source checkout.
  run 'install After Effects MCP dependencies' npm --prefix "$repo" install --package-lock=false
  run 'build After Effects MCP' npm --prefix "$repo" run build
  run 'install the After Effects Mac connection panel' node "$script_dir/scripts/install-ae-mac.mjs" "$repo"
  configure after-effects -- "$(node_path)" "$repo/dist/index.js" serve
  note 'In After Effects: Settings > Scripting & Expressions > Allow Scripts to Write Files and Access Network.'
  note 'Then Window > Creative MCP Bridge.jsx > Connect. See README.md for the Run Script File fallback.'
}
install_premiere() {
  title 'Premiere Pro MCP'
  if [ "$platform" = Linux ]; then
    warning 'Skipped: Adobe Premiere Pro is not supported on Linux.'
    return 0
  fi
  require_command npm 'install Premiere Pro MCP'
  require_command node 'run Premiere Pro MCP'
  local entry="$npm_root/lib/node_modules/premiere-pro-mcp/dist/index.js"
  run 'install Premiere Pro MCP in your user folder' npm install --prefix "$npm_root" -g 'premiere-pro-mcp@1.6.0'
  run 'install the Premiere bridge panel' "$(node_path)" "$entry" --install-cep
  run 'verify the Premiere bridge panel' "$(node_path)" "$entry" --diagnose-cep
  configure premiere-pro -- "$(node_path)" "$entry"
  note 'Restart Premiere Pro > Window > Extensions > MCP Bridge > Start Bridge.'
}
install_unreal() {
  title 'Unreal Engine MCP'
  configure unreal-engine --url 'http://127.0.0.1:8000/mcp'
  note 'Connection configured only; no engine or plugin is downloaded. Enable and start your Unreal loopback MCP server on port 8000.'
}

if [ -z "$selection" ]; then
  if ! read -r -p 'Choose all, godot, blender, after-effects, premiere-pro, or unreal-engine (Enter for all): ' selection; then
    echo 'No selection received. Run with --selection=all or a specific integration.' >&2
    exit 2
  fi
fi
selection="${selection:-all}"
case "$selection" in
  all|godot|blender|after-effects|premiere-pro|unreal-engine) ;;
  *) echo "Unknown choice: $selection" >&2; exit 2 ;;
esac
if [ "$no_config" -eq 0 ]; then
  require_command codex 'configure MCP servers in Codex'
fi
case "$selection" in
  all) install_godot; install_blender; install_after_effects; install_premiere; install_unreal ;;
  godot) install_godot ;;
  blender) install_blender ;;
  after-effects) install_after_effects ;;
  premiere-pro) install_premiere ;;
  unreal-engine) install_unreal ;;
esac
if [ "$dry_run" -eq 1 ]; then
  printf '\nPreview complete. Nothing was installed.\n'
else
  printf '\nInstallation steps completed. Restart Codex, then follow the app-side steps above. Live app connections have not been tested by this installer.\n'
fi
