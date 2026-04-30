# distro

AI agent desktop integration for NixOS. Chat with a local AI agent
directly from your desktop bar.

The stack: [niri](https://github.com/YaLTeR/niri) (Wayland compositor) +
[noctalia](https://github.com/noctalia-dev/noctalia-shell) (desktop shell) +
[opencrow](https://github.com/pinpox/opencrow) (AI agent backend) +
[llama-swap](https://github.com/mostlygeek/llama-swap) (local LLM server).

## Three ways to use it

| Integration | What you get | You provide |
|---|---|---|
| **Full desktop** | Niri compositor, noctalia bar with chat widget, AI agent, local LLM | A NixOS machine |
| **Noctalia bar** | Noctalia bar with chat widget + agent backend | Your own compositor (GNOME, Sway, Hyprland, …) |
| **Noctalia plugin** | Chat widget + agent backend (enabled by default) | An existing noctalia install |

## Binary Cache

Configure the [numtide binary cache](https://cache.numtide.com/index.html) to
avoid building dependencies from source.

## Setup

All three integration levels consume this flake as a NixOS module.

### 1. Full desktop

Import `nixosModules.distro` for the complete experience: niri compositor,
noctalia shell bar with chat widget, opencrow AI agent, and local LLM server.
The module enables the AI agent, chat widget, and greetd auto-login into niri
by default.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    distro.url = "github:numtide/distro";
  };

  outputs = { nixpkgs, distro, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        distro.nixosModules.distro
        {
          # Override the default greetd auto-login user.
          services.greetd.settings.default_session.user = "alice";
        }
      ];
    };
  };
}
```

This gives you:
- **Mod+T** — terminal (alacritty)
- **Mod+D** — app launcher (fuzzel)
- **Mod+N** — toggle the chat panel
- Noctalia bar with system tray, workspaces, and chat widget

### 2. Noctalia bar (any compositor)

Already using GNOME, Sway, Hyprland, or another Wayland compositor? Import
`nixosModules.noctalia-bar` to get the noctalia bar with the AI chat widget.
You keep your compositor.  The module enables the AI agent and chat widget by
default.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    distro.url = "github:numtide/distro";
  };

  outputs = { nixpkgs, distro, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        distro.nixosModules.noctalia-bar
        ./configuration.nix
      ];
    };
  };
}
```

After enabling the NixOS module, open noctalia's **Settings → Plugins** and
enable the **AI Chat** plugin.

Then add `noctalia-shell` to your compositor's autostart:

**Sway**
```
# ~/.config/sway/config
exec noctalia-shell
```

**Hyprland**
```
# ~/.config/hypr/hyprland.conf
exec-once = noctalia-shell
```

### 3. Plugin only (existing noctalia)

Already running noctalia? Import `nixosModules.noctalia-plugin` to add just the
chat widget and agent backend.  The module enables the AI agent and chat widget
by default.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    distro.url = "github:numtide/distro";
  };

  outputs = { nixpkgs, distro, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        distro.nixosModules.noctalia-plugin
        ./configuration.nix
      ];
    };
  };
}
```
After enabling the NixOS module, open noctalia's **Settings → Plugins** and
enable the **AI Chat** plugin. Alternatively, add
`{ id = "plugin:opencrow-chat"; }` to your `settings.json` widget layout.

## License

See [LICENSE](LICENSE).
