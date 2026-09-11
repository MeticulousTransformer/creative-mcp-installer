# Creative MCP Installer

This is a standalone, per-user installer for the creative MCPs in this workspace. It does **not** edit, move, or delete the source folders under `mcp`.

The installer scripts and this guide are available under the [MIT License](LICENSE). The creative MCPs themselves are downloaded separately from their upstream projects and keep their own licenses.

## For the person installing it

1. Copy this entire `MCP-Creative-Installer` folder to the computer.
2. Make sure Codex and the relevant creative apps are already installed.
3. Run the file for that computer:
   - **Windows:** double-click `Install on Windows.bat`.
   - **macOS:** double-click `Install on macOS.command`. If macOS blocks it, right-click it and choose **Open**.
   - **Linux:** in a terminal inside this folder, run `bash "Install on Linux.sh"`.
4. Pick one integration or press Enter to install all compatible integrations.
5. Restart Codex when it finishes, then open the relevant creative app.

The installer needs an internet connection to download official upstream packages. It never starts a publicly reachable server: all configured connections are local to the computer.

## What it installs

| MCP | Windows | macOS | Linux | What the person must do in the creative app |
| --- | --- | --- | --- | --- |
| Godot | Yes | Yes | Yes | Open Godot. Set `GODOT_PATH` only if it is not found automatically. |
| Blender | Yes | Yes | Yes | In Blender, add `https://lab.blender.org/` in Extensions, install/enable **MCP**, and start its local bridge. |
| After Effects | Yes | Not supplied | Not supplied | Enable scripting/network access; open **Window > ae-mcp-status.jsx** and click **CONNECT BRIDGE**. |
| Premiere Pro | Yes | Yes | No Adobe host | Restart Premiere; check **Window > Extensions > MCP Bridge** is running. |
| Unreal Engine | Yes | Engine-dependent | Engine-dependent | In UE 5.8 enable **Unreal MCP**, **Python Editor Script Plugin**, and **EditorToolset**, then start its loopback MCP server. |

After Effects and Premiere require their desktop applications on the same machine as Codex. The Unreal entry points only to `http://127.0.0.1:8000/mcp`; it is local-only and is useful only while Unreal's built-in MCP server is running.

## What changes on the installer’s computer

- Adds a missing named MCP entry to that user’s Codex configuration. It deliberately does not overwrite an existing entry with the same name.
- Installs npm packages globally for Godot and Premiere Pro.
- Places Blender and After Effects dependencies in a separate `~/.creative-mcps` (or equivalent Windows user-profile) folder.
- Installs the official Adobe bridge panels where the upstream MCP requires them.

To preview what the Windows installer would do without installing anything:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-MCPs.ps1 -Selection godot -DryRun
```

On macOS or Linux:

```bash
bash install-mcps.sh --selection=godot --dry-run
```

## Company sharing notes

Share this folder as a ZIP and keep all files together. macOS may require the recipient to allow the `.command` file to open after extracting it. If macOS says the file is not executable, they can run `bash "Install on macOS.command"` from Terminal instead. The installer downloads upstream open-source components at installation time; for a locked-down or offline company environment, mirror/approve those upstream sources through your company’s normal software-distribution process before using this package.

The creative MCPs can control local creative applications. Install them only for trusted users and do not change their default loopback-only networking into a public endpoint.
