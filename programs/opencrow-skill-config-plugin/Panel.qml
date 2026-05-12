import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Single-field input form for the head of the pending-request queue.
// Auto-focuses the input when shown; Enter submits, Esc cancels.
// When the head item is removed (submitted/cancelled/timed out by the
// daemon), the panel either renders the next pending item or closes.
Item {
  id: root

  property var pluginApi: null
  property var main: pluginApi?.mainInstance || null
  readonly property var req: main?.current || null

  function tr(key, args) { return pluginApi?.tr(key, args) ?? key; }

  // SmartPanel sizes by these properties.
  property real contentPreferredWidth: 480
  property real contentPreferredHeight: 280
  implicitWidth: contentPreferredWidth
  implicitHeight: contentPreferredHeight

  // Close the panel when there's nothing pending. The Main component's
  // _drop() has already removed the entry by the time we hit this; the
  // panel closes on its own rather than rendering a blank form.
  onReqChanged: {
    if (!req) main?.closePanel();
    else {
      // New head item — focus the input, clear stale text, and re-apply
      // the echo mode (Password vs Normal) for the new field's secrecy.
      input.text = "";
      input.forceActiveFocus();
      input.applyEcho();
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // ── Header ────────────────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: req?.secret ? "key" : "edit"
        pointSize: Style.fontSizeXL * 1.2
        color: Color.mPrimary
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        // Instance label first — this is the safety signal: the user
        // sees which opencrow asked before they type anything.
        NText {
          text: req ? ("opencrow-" + req.instance) : ""
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
        NText {
          text: req ? (req.skill + " · " + req.profile + " · " + req.field) : ""
          pointSize: Style.fontSizeL
          font.bold: true
        }
      }
    }

    // ── Description ───────────────────────────────────────────────────
    NText {
      Layout.fillWidth: true
      // Markdown so SKILL.md can use bold, lists, and blank-line
      // paragraph breaks for readable per-field guidance.
      markdownTextEnabled: true
      text: req?.description ?? ""
      wrapMode: Text.Wrap
      color: Color.mOnSurfaceVariant
    }

    // ── Input ─────────────────────────────────────────────────────────
    NTextInput {
      id: input
      Layout.fillWidth: true
      placeholderText: req?.secret
        ? root.tr("panel.placeholder-secret")
        : root.tr("panel.placeholder-value")
      // Mask input for secret fields. Quickshell's NTextInput exposes
      // an inputItem; we set echoMode through it. Re-applied from root's
      // onReqChanged when the head item changes.
      Component.onCompleted: applyEcho()
      function applyEcho() {
        if (inputItem)
          inputItem.echoMode = req?.secret ? TextInput.Password : TextInput.Normal;
      }
      inputItem.Keys.onReturnPressed: e => root._submit()
      inputItem.Keys.onEscapePressed: e => root._cancel()
    }

    Item { Layout.fillHeight: true }  // spacer

    // ── Buttons ───────────────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NText {
        Layout.fillWidth: true
        // Pending-count hint when a queue is forming behind the
        // current request. Reassures the user there'll be more popups.
        text: {
          const n = main?.pending?.length ?? 0;
          return n > 1 ? root.tr("panel.queue-hint", { n: (n - 1) }) : "";
        }
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
      }
      NButton {
        text: root.tr("panel.cancel")
        outlined: true
        onClicked: root._cancel()
      }
      NButton {
        text: root.tr("panel.submit")
        enabled: input.text.length > 0
        onClicked: root._submit()
      }
    }
  }

  function _submit() {
    if (!req || !input.text) return;
    main?.submit(req.request_id, input.text);
    input.text = "";  // wipe before any redraw
  }

  function _cancel() {
    if (!req) return;
    main?.cancel(req.request_id);
    input.text = "";
  }
}
