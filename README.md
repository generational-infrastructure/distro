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
| **Noctalia plugin** | Chat widget + agent backend | An existing noctalia install |

## Binary Cache

Configure the [numtide binary cache](https://cache.numtide.com/index.html) to
avoid building dependencies from source.

## Setup

All three integration levels consume this flake as a NixOS module. Add it to
your flake inputs:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    distro.url = "github:numtide/distro";
  };

  outputs = { nixpkgs, distro, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      specialArgs = { inputs = distro.inputs // { distro = distro; }; };
      modules = [
        # Pick ONE of the three modules below
        distro.nixosModules.distro          # Full desktop
        # distro.nixosModules.noctalia-bar  # Bar only
        # distro.nixosModules.noctalia-plugin  # Plugin only
        ./configuration.nix
      ];
    };
  };
}
```

### 1. Full desktop

Import `nixosModules.distro` for the complete experience: niri compositor,
noctalia shell bar with chat widget, opencrow AI agent, and local LLM server.

```nix
# configuration.nix
{ config, inputs, ... }:
{
  # Auto-login into niri (adjust to your display manager)
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${config.programs.niri.package}/bin/niri-session";
      user = "alice";
    };
  };

  # AI agent with chat widget in the bar
  services.opencrow-local = {
    enable = true;
    noctaliaPlugin = true;
    piPackage = inputs.distro.inputs.llm-agents.packages.x86_64-linux.pi;
  };

  # Local LLM server
  services.llama-swap.enable = true;
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
You keep your compositor.

```nix
# configuration.nix
{ inputs, ... }:
{
  services.opencrow-local = {
    enable = true;
    noctaliaPlugin = true;
    piPackage = inputs.distro.inputs.llm-agents.packages.x86_64-linux.pi;
  };

  services.llama-swap.enable = true;
}
```

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
chat widget and agent backend.

```nix
# configuration.nix
{ inputs, ... }:
{
  services.opencrow-local = {
    enable = true;
    noctaliaPlugin = true;
    piPackage = inputs.distro.inputs.llm-agents.packages.x86_64-linux.pi;
  };

  services.llama-swap.enable = true;
}
```

The plugin appears in noctalia's plugin list. Enable it from the bar settings,
or add `{ id = "plugin:opencrow-chat"; }` to your `settings.json` widget
layout.

## Architecture

```
┌─────────────────────────────────────────────────┐
│ Desktop (niri / sway / …)                       │
│  ┌────────────────────────────────────────────┐ │
│  │ Noctalia bar                               │ │
│  │  [Launcher] [Clock] ... [Chat Widget] ...  │ │
│  └──────────────────────┬─────────────────────┘ │
│                         │ UNIX socket            │
│                     opencrow (agent)             │
│                         │                        │
└─────────────────────────┼───────────────────────┘
                          │
                     llama-swap (LLM)
```

## License

See [LICENSE](LICENSE).
