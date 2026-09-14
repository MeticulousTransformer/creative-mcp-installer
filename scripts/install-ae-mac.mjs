import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const template = new URL('./Creative MCP Bridge.jsx', import.meta.url);

export function installMacBridge(packageRoot, preferencesRoot = path.join(os.homedir(), 'Library/Preferences/Adobe/After Effects')) {
  const hostScripts = path.join(path.resolve(packageRoot), 'host-scripts');
  for (const name of ['ae-mcp-engine.jsx', 'ae-mcp-methods.jsx']) {
    if (!fs.existsSync(path.join(hostScripts, name))) throw new Error(`Missing ${path.join(hostScripts, name)}`);
  }
  const panel = fs.readFileSync(template, 'utf8').replace('__HOST_SCRIPTS__', () => JSON.stringify(hostScripts));
  const fallback = path.join(packageRoot, 'Creative MCP Bridge.jsx');
  fs.writeFileSync(fallback, panel);
  const panels = [];
  if (fs.existsSync(preferencesRoot)) {
    for (const version of fs.readdirSync(preferencesRoot, { withFileTypes: true })) {
      if (!version.isDirectory() || !/^\d+\.\d+$/.test(version.name)) continue;
      const dir = path.join(preferencesRoot, version.name, 'Scripts', 'ScriptUI Panels');
      fs.mkdirSync(dir, { recursive: true });
      const target = path.join(dir, 'Creative MCP Bridge.jsx');
      fs.writeFileSync(target, panel);
      panels.push(target);
    }
  }
  return { panels, fallback };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    if (process.platform !== 'darwin') throw new Error('This bridge installer requires macOS.');
    if (!process.argv[2]) throw new Error('Usage: node install-ae-mac.mjs <after-effects-mcp-folder>');
    const result = installMacBridge(process.argv[2]);
    for (const panel of result.panels) console.log(`Installed: ${panel}`);
    if (!result.panels.length) console.log('No After Effects user preferences found. Open AE once and rerun to add the Window panel.');
    console.log(`Available now via File > Scripts > Run Script File: ${result.fallback}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
