// macOS adapter for HeroicSwan/after-effects-mcp at e38b2609.
// The installer substitutes the absolute package path. No Startup script needed.
(function (thisObj) {
  var hostScripts = __HOST_SCRIPTS__;
  var win = thisObj instanceof Panel ? thisObj : new Window('palette', 'Creative MCP Bridge');
  win.orientation = 'column';
  win.alignChildren = ['fill', 'top'];
  win.add('statictext', undefined, 'Enable Allow Scripts to Write Files and Access Network\nin Settings > Scripting & Expressions first.', { multiline: true });
  var status = win.add('statictext', undefined, 'Disconnected', { multiline: true });
  status.preferredSize = [400, 60];
  var connect = win.add('button', undefined, 'Connect');
  var disconnect = win.add('button', undefined, 'Disconnect');

  connect.onClick = function () {
    try {
      // Verify file access before starting a poller which otherwise swallows errors.
      var data = new Folder(Folder('~').fsName + '/.ae-mcp');
      if (!data.exists && !data.create()) throw new Error('Cannot create the bridge folder. Enable scripting file access.');
      var probe = new File(data.fsName + '/mac-panel-write-test');
      if (!probe.open('w')) throw new Error('Enable Allow Scripts to Write Files and Access Network, then connect again.');
      probe.write('ok');
      probe.close();
      probe.remove();

      // Preload both scripts: upstream loaders require Windows APPDATA.
      $.evalFile(new File(hostScripts + '/ae-mcp-methods.jsx'));
      if (!$.global.__AE_MCP_DISPATCH__) throw new Error('The MCP methods could not be loaded. Rerun the installer.');
      $.global.__AE_MCP_METHODS_VERSION__ = 3;
      $.evalFile(new File(hostScripts + '/ae-mcp-engine.jsx'));
      if (!$.global.__AE_MCP_RESTART_POLLER__) throw new Error('The MCP engine could not be loaded. Restart AE and rerun the installer.');
      $.global.__AE_MCP_RESTART_POLLER__();
      if (!$.global.__AE_MCP_TASK_ID__) throw new Error('Close any open dialogs, then click Connect again.');
      status.text = 'Connected. Leave After Effects open while using Codex.';
    } catch (error) {
      status.text = 'Could not connect: ' + String(error);
    }
    win.layout.layout(true);
  };
  disconnect.onClick = function () {
    if ($.global.__AE_MCP_TASK_ID__) app.cancelTask($.global.__AE_MCP_TASK_ID__);
    $.global.__AE_MCP_TASK_ID__ = null;
    $.global.__AE_MCP_CHAIN_STARTED__ = false;
    $.global.__AE_MCP_POLLER_ON__ = false;
    status.text = 'Disconnected.';
  };
  win.layout.layout(true);
  if (win instanceof Window) { win.center(); win.show(); }
})(this);
