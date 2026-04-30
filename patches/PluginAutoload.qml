pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons

// Auto-enable plugins discovered under `~/.config/noctalia/plugins-autoload/`.
//
// This singleton is invoked from two minimal hook points in upstream code:
//   1. PluginRegistry.scanPluginFolder() — after the main scan completes,
//      we scan the autoload dir, register any new plugins as enabled, and
//      persist via PluginRegistry.save().
//   2. PluginService._onPluginLoadComplete() — after all enabled plugins
//      finish loading, we add bar widgets for the newly autoloaded ones.
//
// Keeping the logic here means upstream files only carry a 1-line call,
// reducing merge-conflict surface area.
Singleton {
  id: root

  readonly property string autoloadDir: Settings.configDir + "plugins-autoload"

  // Plugin IDs autoloaded during this session (cleared after widgets are added).
  property var pendingAutoloads: ({})

  // Plugin IDs already known from plugins.json before this session started.
  // The regular plugin scan adds entries to pluginStates with enabled:false,
  // so we need a snapshot from BEFORE that to know what's actually new.
  property var initialKnownPlugins: ({})

  Component.onCompleted: {
    // Read plugins.json to capture user state before noctalia adds scan entries.
    var snap = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["sh", "-c", "cat '${PluginRegistry.pluginsFile}' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {}
        running: true
      }
    `, root, "AutoloadSnapshot");
    snap.exited.connect(function () {
      try {
        var data = JSON.parse(String(snap.stdout.text || "{}"));
        var states = data.states || {};
        for (var k in states) {
          root.initialKnownPlugins[k] = true;
        }
      } catch (e) {
        Logger.w("PluginAutoload", "Failed to snapshot plugins.json:", e.toString());
      }
      snap.destroy();
    });
  }

  // Scan the autoload dir; for each plugin not already in pluginStates,
  // mark it enabled and remember it for bar-widget placement.
  function processAutoloadDir() {
    Logger.i("PluginAutoload", "Scanning autoload dir:", root.autoloadDir);
    var scan = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["sh", "-c", "for d in '${root.autoloadDir}'/*/; do [ -d \\"$d\\" ] || continue; [ -f \\"$d/manifest.json\\" ] || continue; basename \\"$d\\"; done"]
        stdout: StdioCollector {}
        running: true
      }
    `, root, "AutoloadScan");

    scan.exited.connect(function (exitCode) {
      var ids = String(scan.stdout.text || "").trim().split("\n").filter(function (s) {
        return s.length > 0;
      });
      var changed = false;
      for (var i = 0; i < ids.length; i++) {
        var pid = ids[i];
        // Use the pre-scan snapshot: if the plugin wasn't in plugins.json
        // before this session, this is its first discovery \u2192 auto-enable.
        if (!root.initialKnownPlugins[pid]) {
          PluginRegistry.pluginStates[pid] = { enabled: true };
          root.pendingAutoloads[pid] = { barSection: "center" };
          Logger.i("PluginAutoload", "Auto-enabled plugin:", pid);
          changed = true;
        }
      }
      if (changed) {
        PluginRegistry.pluginsChanged();
        // Persist plugins.json directly via shell.  PluginRegistry.save() goes
        // through FileView.writeAdapter(), which can silently no-op when the
        // initial load failed before ensurePluginsFile created the file.
        var json = JSON.stringify({
          version: PluginRegistry.currentVersion,
          states: PluginRegistry.pluginStates,
          sources: PluginRegistry.pluginSources || []
        });
        var path = PluginRegistry.pluginsFile;
        // Pass JSON via base64 to dodge any shell-quoting ambiguity.
        var b64 = Qt.btoa(json);
        var write = Qt.createQmlObject(
          'import QtQuick; import Quickshell.Io; '
          + 'Process { stdout: StdioCollector {} }',
          root, "AutoloadWrite");
        write.command = ["sh", "-c", "echo '" + b64 + "' | base64 -d > '" + path + "'"];
        write.running = true;
      }
      scan.destroy();
    });
  }

  // Called from PluginService once all enabled plugins finished loading.
  // Adds bar widgets for plugins that were autoloaded in this session.
  function addAutoloadedWidgets() {
    for (var pid in root.pendingAutoloads) {
      var manifest = PluginRegistry.getPluginManifest(pid);
      if (manifest && manifest.entryPoints && manifest.entryPoints.barWidget) {
        var widgetId = "plugin:" + pid;
        var section = root.pendingAutoloads[pid].barSection || "right";
        PluginService.addWidgetToBar(widgetId, section);
        Logger.i("PluginAutoload", "Added autoloaded bar widget:", widgetId, "to", section);
      }
    }
    root.pendingAutoloads = ({});
  }
}
