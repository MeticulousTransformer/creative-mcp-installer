import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';

test('Mac installer puts a standalone panel into existing user AE versions, including paths with spaces', async t => {
  const { installMacBridge } = await import('../scripts/install-ae-mac.mjs');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'AE Mac test '));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const repo = path.join(dir, 'package');
  fs.mkdirSync(path.join(repo, 'host-scripts'), { recursive: true });
  for (const file of ['ae-mcp-engine.jsx', 'ae-mcp-methods.jsx']) {
    fs.writeFileSync(path.join(repo, 'host-scripts', file), '// fixture');
  }
  const prefs = path.join(dir, 'Preferences');
  fs.mkdirSync(path.join(prefs, '26.2'), { recursive: true });
  fs.mkdirSync(path.join(prefs, 'Logs'));
  const result = installMacBridge(repo, prefs);
  const target = path.join(prefs, '26.2', 'Scripts', 'ScriptUI Panels', 'Creative MCP Bridge.jsx');
  assert.deepEqual(result.panels, [target]);
  assert.equal(fs.readFileSync(target, 'utf8'), fs.readFileSync(result.fallback, 'utf8'));
  assert.equal(fs.existsSync(path.join(prefs, 'Logs', 'Scripts')), false);
  assert.equal(fs.existsSync(path.join(prefs, '26.2', 'Scripts', 'Startup')), false);
  // Rerunning replaces only our own panel, preserving other installed scripts.
  const other = path.join(path.dirname(target), 'my-script.jsx');
  fs.writeFileSync(other, 'keep me');
  installMacBridge(repo, prefs);
  assert.equal(fs.readFileSync(other, 'utf8'), 'keep me');
});

test('Mac panel stays inert until Connect, loads methods before engine, and can disconnect', () => {
  const loaded = [];
  const buttons = {};
  const state = {};
  const elements = [];
  const context = {
    Panel: function Panel() {},
    Window: function Window() {
      this.add = (type, unused, text) => {
        const element = { text };
        elements.push(element);
        if (type === 'button') buttons[text] = element;
        return element;
      };
      this.layout = { layout() {} };
      this.center = this.show = () => {};
    },
    Folder: function Folder(name) { this.fsName = name; this.exists = true; },
    File: function File(name) {
      this.name = name;
      this.open = () => true;
      this.write = this.close = this.remove = () => {};
    },
    app: { cancelTask(id) { assert.equal(id, 42); } },
    $: { global: state, evalFile(file) {
      loaded.push(file.name);
      if (file.name.endsWith('ae-mcp-methods.jsx')) state.__AE_MCP_DISPATCH__ = () => {};
      else state.__AE_MCP_RESTART_POLLER__ = () => { state.__AE_MCP_TASK_ID__ = 42; };
    } },
  };
  // ExtendScript permits Folder('~') without `new`.
  context.Folder = function (name) { return { fsName: name, exists: true }; };
  const code = fs.readFileSync(new URL('../scripts/Creative MCP Bridge.jsx', import.meta.url), 'utf8')
    .replace('__HOST_SCRIPTS__', JSON.stringify('/Mac user/AE package/host-scripts'));
  vm.runInNewContext(code, context);
  assert.deepEqual(loaded, []);
  buttons.Connect.onClick();
  assert.deepEqual(loaded, ['/Mac user/AE package/host-scripts/ae-mcp-methods.jsx', '/Mac user/AE package/host-scripts/ae-mcp-engine.jsx']);
  assert.ok(elements.some(element => element.text.startsWith('Connected.')));
  buttons.Disconnect.onClick();
  assert.equal(state.__AE_MCP_TASK_ID__, null);
  assert.equal(state.__AE_MCP_POLLER_ON__, false);
});

test('missing upstream engine fails before installing a misleading panel', async t => {
  const { installMacBridge } = await import('../scripts/install-ae-mac.mjs');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'AE missing '));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  assert.throws(() => installMacBridge(dir, path.join(dir, 'prefs')), /Missing/);
  assert.equal(fs.existsSync(path.join(dir, 'Creative MCP Bridge.jsx')), false);
});
