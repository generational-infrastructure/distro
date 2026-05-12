import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// State owner for the skill-config plugin. Holds a long-lived
// `subscribe` connection to /run/opencrow-<inst>/skill-config.sock
// (via $XDG_RUNTIME_DIR/opencrow-skill-config.sock symlink), tracks
// pending input requests, and exposes submit/cancel actions.
//
// Submit/cancel use fresh short-lived connections so the subscribe
// stream stays purely incoming (matches the daemon's protocol — its
// subscribe handler doesn't read further messages from subscribers).
//
// Auto-show: when `pending` transitions from empty → non-empty, the
// panel opens. Subsequent items just update the form to the new head.
Item {
  id: root

  property var pluginApi: null

  // Daemon socket path. The opencrow nix module sets up a user-systemd
  // unit that symlinks $XDG_RUNTIME_DIR/opencrow-skill-config.sock to
  // /run/opencrow-<instance>/skill-config.sock — same pattern as the
  // chat socket.
  readonly property string sockPath:
    String(Quickshell.env("XDG_RUNTIME_DIR")) + "/opencrow-skill-config.sock"

  // The model: array of pending request objects, in arrival order.
  // { request_id, instance, skill, profile, field, description, secret }
  property var pending: []

  // Convenience: the head of the queue, what the panel renders.
  readonly property var current: pending.length > 0 ? pending[0] : null

  function findIndex(rid) {
    for (let i = 0; i < pending.length; i++)
      if (pending[i].request_id === rid) return i;
    return -1;
  }

  function _push(req) {
    if (findIndex(req.request_id) >= 0) return;
    const wasEmpty = pending.length === 0;
    pending = pending.concat([req]);
    if (wasEmpty) showPanel();
  }

  function _drop(rid) {
    const i = findIndex(rid);
    if (i < 0) return;
    const arr = pending.slice();
    arr.splice(i, 1);
    pending = arr;
  }

  function showPanel() {
    if (pluginApi?.panelOpenScreen) return;
    pluginApi?.withCurrentScreen(s => pluginApi.openPanel(s));
  }

  function closePanel() {
    pluginApi?.withCurrentScreen(s => pluginApi.closePanel(s));
  }

  // Persistent subscribe connection. Recreated on each reconnect using
  // the same Loader trick the chat plugin uses — Quickshell's Socket
  // gets wedged after a refused/missing connect, so we destroy and
  // rebuild rather than re-dial in place.
  Loader {
    id: sub
    sourceComponent: subComponent
    readonly property bool connected: item?.connected ?? false
  }
  Component {
    id: subComponent
    Socket {
      path: root.sockPath
      connected: true
      parser: SplitParser { onRead: line => root._onSubLine(line) }
      onConnectionStateChanged: {
        if (connected) {
          reconnect.stop();
          reconnect.interval = 500;
          // Initiate the subscription. The daemon will reply with a
          // snapshot and then push added/removed events on this
          // connection until either side closes it.
          write(JSON.stringify({ op: "subscribe" }) + "\n");
          flush();
        } else {
          // Container restarted, daemon crashed, etc. — drop our model
          // (we no longer trust it) and reconnect; the next snapshot
          // will rebuild it.
          root.pending = [];
          reconnect.start();
        }
      }
      onError: (e) => {
        Logger.w("OpencrowSkillConfig", "subscribe socket", e, "path", path);
        reconnect.start();
      }
    }
  }
  Timer {
    id: reconnect
    interval: 500
    onTriggered: {
      sub.active = false; sub.active = true;
      interval = Math.min(interval * 2, 4000);
    }
  }

  // One NDJSON line from the daemon's subscribe stream.
  function _onSubLine(raw) {
    let ev;
    try { ev = JSON.parse(raw); }
    catch (e) { Logger.w("OpencrowSkillConfig", "bad ipc json", raw); return; }

    switch (ev.op) {
    case "snapshot": {
      // Reset the model from authoritative server state. Stamp each
      // entry with the instance for display.
      const arr = (ev.requests || []).map(r => Object.assign({}, r, { instance: ev.instance }));
      const wasEmpty = root.pending.length === 0;
      root.pending = arr;
      if (wasEmpty && arr.length > 0) showPanel();
      break;
    }
    case "added": {
      const r = Object.assign({}, ev.request, { instance: ev.instance });
      root._push(r);
      break;
    }
    case "removed":
      root._drop(ev.request_id);
      break;
    default:
      Logger.w("OpencrowSkillConfig", "unknown event op", ev.op);
    }
  }

  // ── Submit / cancel ────────────────────────────────────────────────
  // Each action opens a fresh short connection to the same socket and
  // sends a single op. The daemon dispatches it to the waiting CLI;
  // we don't need to wait for the {"op":"ok"} ack here because the
  // subsequent `removed` event on the subscribe stream is the real
  // confirmation.

  Component {
    id: oneShotComponent
    Socket {
      property var payload: null
      // Gate the dial on `path` being set. `connected: true` as an
      // unconditional literal triggers a connect at the default empty
      // path before createObject's initial properties are applied —
      // QLocalSocket then wedges (see chat plugin's Loader comment).
      connected: path !== ""
      onConnectionStateChanged: {
        if (!connected) return;
        write(JSON.stringify(payload) + "\n");
        flush();
        // Closes itself once daemon writes the ack and disconnects, or
        // we destroy the loader explicitly. Leaving it for one ack read
        // is good practice — but ack content is the same as `removed`
        // event we'll see anyway.
      }
      onError: (e) => Logger.w("OpencrowSkillConfig", "one-shot send", e)
      parser: SplitParser { onRead: () => {} }  // ignore the ack
    }
  }

  function _send(payload) {
    const c = oneShotComponent.createObject(root, {
      path: root.sockPath,
      payload: payload,
    });
    // The Socket auto-disconnects once the daemon closes its end after
    // the ack; we destroy our wrapper on a short delay to be safe.
    Qt.callLater(() => c.destroy(2000));
  }

  function submit(rid, value) {
    _send({ op: "submit", request_id: rid, value: value });
    // Optimistically drop locally — the matching `removed` event will
    // confirm. If submit fails (e.g., already cancelled), the daemon's
    // pending list is authoritative; we'll see the truth via subscribe.
  }

  function cancel(rid) {
    _send({ op: "cancel", request_id: rid });
  }
}
