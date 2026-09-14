import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');

// Only external commands are faked: exercise the actual shell installer.
function installer(t, npmExit = 0, codexExit = 0, extraArgs = [], existing = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'creative installer '));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const log = path.join(dir, 'commands');
  for (const [command, body] of Object.entries({
    npm: `printf '%s\\n' "$*" >> "$TEST_COMMAND_LOG"\nexit ${npmExit}`,
    codex: `if [ "$2" = get ]; then exit ${existing ? 0 : 1}; fi\nprintf 'codex %s\\n' "$*" >> "$TEST_COMMAND_LOG"\nexit ${codexExit}`,
  })) fs.writeFileSync(path.join(dir, command), '#!/bin/bash\n' + body + '\n', { mode: 0o755 });
  const result = spawnSync('/bin/bash', [path.join(root, 'install-mcps.sh'), '--selection=godot', ...extraArgs], {
    encoding: 'utf8', env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, TEST_COMMAND_LOG: log },
  });
  return { ...result, log: fs.existsSync(log) ? fs.readFileSync(log, 'utf8') : '' };
}

test('failed npm installation stops before Codex configuration and success message', t => {
  const result = installer(t, 13);
  assert.notEqual(result.status, 0);
  assert.doesNotMatch(result.log, /codex mcp add/);
  assert.doesNotMatch(result.stdout, /Finished|Installation complete/);
});

test('existing Codex entries are preserved until replace-config is explicitly supplied', t => {
  const preserved = installer(t, 0, 0, [], true);
  assert.equal(preserved.status, 0);
  assert.doesNotMatch(preserved.log, /codex mcp add/);
  assert.match(preserved.stdout, /left unchanged/);
  const repaired = installer(t, 0, 0, ['--replace-config'], true);
  assert.equal(repaired.status, 0);
  assert.match(repaired.log, /codex mcp add godot -- \/.+/);
});

test('no-config installs packages without invoking Codex configuration', t => {
  const result = installer(t, 0, 7, ['--no-config']);
  assert.equal(result.status, 0);
  assert.doesNotMatch(result.log, /codex/);
});

test('EOF without an explicit selection does not install everything', () => {
  const result = spawnSync('/bin/bash', [path.join(root, 'install-mcps.sh')], { input: '', encoding: 'utf8' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /No selection received/);
});

test('npm packages use a user prefix and Codex receives an absolute executable', t => {
  const result = installer(t);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.log, /--prefix .*\.creative-mcps\/npm/);
  assert.match(result.log, /codex mcp add godot -- \/.+/);
});

test('failed Codex configuration cannot report success', t => {
  const result = installer(t, 0, 7);
  assert.notEqual(result.status, 0);
  assert.doesNotMatch(result.stdout, /Added godot|Finished|Installation complete/);
});

test('dry run previews macOS After Effects without writing or invoking installers', () => {
  const result = spawnSync('/bin/bash', [path.join(root, 'install-mcps.sh'), '--selection=after-effects', '--dry-run'], { encoding: 'utf8' });
  assert.equal(result.status, 0);
  if (process.platform === 'darwin') {
    assert.match(result.stdout, /Dry run:.*After Effects/);
    assert.doesNotMatch(result.stderr, /Windows only/);
  }
});
