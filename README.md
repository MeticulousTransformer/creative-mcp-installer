# Creative MCP Installer

Install local creative-app MCP integrations for Codex. Packages live in your user folder; this installer does not change other MCP source folders in your workspace.

## Quick start

1. Install the requirements below and open each creative app once.
2. Keep this entire folder together, including `scripts`.
3. Run the launcher for your computer:
   - **macOS:** double-click **Install on macOS.command**.
   - **Windows:** double-click **Install on Windows.bat**.
   - **Linux:** run `bash "Install on Linux.sh"` in this folder.
4. Choose an integration, or press Enter for all compatible integrations.
5. Restart Codex and follow the app-side steps printed by the installer.

On macOS, if double-clicking fails, open Terminal in this folder and run:

```bash
bash "Install on macOS.command"
```

The macOS launcher keeps the result visible until you press Enter and saves a log under `~/.creative-mcps/logs/`. You do not need `sudo` or a system-wide npm install.

## Requirements

- **Codex**, with the `codex` command available in Terminal. The Mac installer also checks the standard Codex app and Homebrew locations.
- **Node.js 20.19+ and npm** for Godot, Premiere, and After Effects. Use a supported Node LTS installer from [nodejs.org](https://nodejs.org/en/download).
- **Python 3.11+** and **Git** for Blender; Git is also needed for After Effects. On Windows the Python command must be `python`; on macOS/Linux it must be `python3`.
- The relevant creative applications, installed separately, and an internet connection.

Check the commands in a new Terminal after installing them:

```bash
codex --version
node --version
npm --version
python3 --version
git --version
```

On macOS, Git is provided by Apple's Command Line Tools (`xcode-select --install`). Python is available from [python.org](https://www.python.org/downloads/). Missing commands produce an error before their integration installs; Codex is checked before any package installation unless `--no-config` is used.

## Integrations and app-side setup

| MCP | Windows | macOS | Linux | After installation |
| --- | --- | --- | --- | --- |
| Godot | Yes | Yes | Yes | Install/open Godot; set `GODOT_PATH` in Codex if detection fails. |
| Blender | Yes | Yes | Yes | Preferences > Get Extensions: add `https://lab.blender.org/`, install/enable **MCP**, then start its local bridge. |
| After Effects | Upstream bridge | Mac connection panel | No Adobe host | See the Mac instructions below; Windows uses **Window > ae-mcp-status.jsx > CONNECT BRIDGE**. |
| Premiere Pro | Yes | Yes | No Adobe host | Restart Premiere > **Window > Extensions > MCP Bridge > Start Bridge**. Set the panel's temp directory if requested. |
| Unreal Engine | Connection only | Connection only | Connection only | Enable/start an MCP server in a compatible Unreal installation on `http://127.0.0.1:8000/mcp`. No engine or plugin is downloaded. |

Installing an MCP package does not install its creative application or prove that the application is connected. Premiere's panel installation is checked automatically; the app must still be opened and its bridge started. The upstream CEP installer enables Adobe's unsigned-extension setting for this panel.

## After Effects on macOS

The installer downloads and builds [HeroicSwan/after-effects-mcp](https://github.com/HeroicSwan/after-effects-mcp), then adds **Creative MCP Bridge.jsx** to the existing After Effects user-version folders:

```text
~/Library/Preferences/Adobe/After Effects/<version>/Scripts/ScriptUI Panels/
```

1. In After Effects, enable **Settings > Scripting & Expressions > Allow Scripts to Write Files and Access Network**.
2. Open **Window > Creative MCP Bridge.jsx** and click **Connect** after dismissing any open dialogs.
3. Leave After Effects open and restart Codex to load the new MCP entry. Connect again after restarting After Effects.

If the panel is missing from Window, restart After Effects. If you have just installed a new AE version, open it once and rerun this installer. You can also use **File > Scripts > Run Script File** and select:

```text
~/.creative-mcps/after-effects-mcp/Creative MCP Bridge.jsx
```

Adobe documents both the Window-panel and Run Script File workflows in its [scripting guide](https://helpx.adobe.com/ca/after-effects/desktop/automate-in-after-effects/automate-animation/scripts.html).

Check the connected bridge from Terminal:

```bash
node "$HOME/.creative-mcps/after-effects-mcp/dist/index.js" health
```

The Mac adapter loads upstream's existing methods and engine directly, bypassing their Windows-only `APPDATA` loaders. It does not run scripts at startup or install into `/Applications`. Use the panel's **Connect** button for reconnection; upstream's Windows-style `ensure` command is not the Mac setup path.

The Mac source revision is pinned to `e38b2609cde262822b888e815684117b35447b11`, whose method-loader version the panel supports. This upstream revision has an inconsistent lockfile, so installation uses `npm install --package-lock=false`; dependency versions still follow upstream's declared ranges. An existing source checkout with another revision or tracked edits is left untouched with an error instead of being reset.

## Retry or repair an older installation

The installer stops on the first failure and returns a nonzero exit code. Fix the displayed error and rerun the same selection; completed package installations can be reused. It never prints completion after a failed command.

Existing Codex entries are preserved by default. If an older failed installer left an entry pointing at a missing executable, repair that integration with:

```bash
bash install-mcps.sh --selection=godot --replace-config
```

Substitute `premiere-pro`, `blender`, or `after-effects` as appropriate. `--replace-config` replaces the selected entry, including any custom settings on that entry; use it only for entries you want to reset. On Windows use `-Selection godot -ReplaceConfig` with `Install-MCPs.ps1`.

Godot and Premiere now install under `~/.creative-mcps/npm`, avoiding `/usr/local/lib/node_modules` permission errors. New Codex entries use absolute executable/script paths, so they do not depend on Codex inheriting your Terminal PATH. Your general npm configuration is left unchanged.

To preview without installing or configuring anything:

```bash
bash install-mcps.sh --selection=all --dry-run
```

On Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-MCPs.ps1 -Selection all -DryRun
```

Use `--no-config` (Windows: `-NoConfig`) to install packages without modifying Codex.

## Verification and maintenance

Run the installer regression tests without downloading packages or changing Codex:

```bash
node --test tests/*.test.mjs
bash -n install-mcps.sh
```

Verified on Apple Silicon with After Effects **26.2.1**: user-panel discovery, Connect, live health response, MCP initialization, and a read-only `ae_get_project_info` call. Other After Effects versions and the updated Windows installer still need platform testing. Rendering and the full upstream tool catalog were not exercised.

The scripts and this guide use the [MIT License](LICENSE). Downloaded MCP projects keep their own licenses. Share the whole folder as a ZIP, preserving executable permissions when possible; the `bash` fallback works if extraction loses them. Connections remain local: do not expose the app bridges publicly.
