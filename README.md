# distro

Reusable NixOS building blocks for the Local AI OS POC.

The first target is a single-user setup:

- a **desktop** daily driver using the NNN stack: NixOS + Niri + Noctalia
- a **server** GPU box that exposes self-hosted OpenAI-compatible inference
- a localhost **LLM router** on the desktop that keeps small requests local and offloads larger/tool requests to the server

## NixOS modules

### `nixosModules.desktop`

Daily-driver profile. Imports:

- `nixosModules.nnn` — Niri scrollable tiling + Noctalia shell
- `nixosModules.llm-client` — `ask-local` + `llm-router`

Example:

```nix
{
  inputs.distro.url = "github:generational-infrastructure/distro";

  outputs = { distro, nixpkgs, ... }: {
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        distro.nixosModules.desktop
        {
          # Route large/tool requests to your own GPU server over your mesh.
          distro.llm-client.router.upstreamEndpoint = "http://gpu-server.mesh:8012";
        }
      ];
    };
  };
}
```

The profile exports:

```sh
OPENAI_BASE_URL=http://127.0.0.1:8090/v1
```

so OpenAI-compatible clients can talk to the local router by default.

### `nixosModules.server`

Headless GPU offload profile. Imports `nixosModules.llm-server`, which enables `services.llama-swap`.

```nix
{
  imports = [ distro.nixosModules.server ];

  # Expose only on a private mesh interface, not the public Internet.
  distro.llm-server.firewallInterfaces = [ "wg0" ];

  # Optional: narrow CUDA builds for the actual GPU generation.
  # distro.llm-server.cudaCapabilities = [ "12.0" ]; # RTX 5090 / Blackwell class
}
```

### `nixosModules.llama-swap`

Wraps the upstream `services.llama-swap` module with a batteries-included local LLM setup:

- `llama-cpp` built with Vulkan + BLAS, and CUDA when `hardware.nvidia.enabled = true`
- default OpenAI-compatible endpoint on port `8012`
- default `gemma4:e4b` model pinned in the Nix store
- Unix socket proxy at `/run/llama-swap.sock` for rootless containers
- cache-directory fix for llama.cpp model downloads
- suspend/resume helpers to release GPU VRAM across sleep cycles

```nix
{
  imports = [ distro.nixosModules.llama-swap ];
  services.llama-swap.enable = true;
}
```

### Lower-level modules

- `nixosModules.nnn` — just the NNN desktop substrate
- `nixosModules.llm-client` — desktop LLM client/router services
- `nixosModules.llm-server` — server-side llama-swap offload endpoint

## Hardware profiles

These are hardware-only modules. Combine one with `desktop` or `server` and a machine-local `hardware-configuration.nix`.

### `nixosModules.hardware-asus-rog-zephyrus-g16-2025`

ASUS ROG Zephyrus G16 / GU605CW-class laptop: Intel display iGPU + NVIDIA Blackwell dGPU.

```nix
{
  imports = [
    distro.nixosModules.desktop
    distro.nixosModules.hardware-asus-rog-zephyrus-g16-2025
    ./hardware-configuration.nix
  ];
}
```

Defaults to latest kernel, NVIDIA open driver, CUDA capability `12.0`, and NVIDIA Container Toolkit.

### `nixosModules.hardware-asus-rog-flow-z13-2025`

ASUS ROG Flow Z13 / GZ302-class tablet laptop: AMD Strix Halo / Ryzen AI Max with high-memory Radeon iGPU.

```nix
{
  imports = [
    distro.nixosModules.desktop
    distro.nixosModules.hardware-asus-rog-flow-z13-2025
    ./hardware-configuration.nix
  ];

  # Optional while ROCm support for this generation settles.
  # distro.hardware.asus-rog-flow-z13-2025.rocmOpencl.enable = true;
}
```

The local LLM lane remains llama.cpp/Vulkan by default.

### `nixosModules.hardware-dual-rtx5090`

Dual RTX 5090 / Blackwell inference workstation.

```nix
{
  imports = [
    distro.nixosModules.server
    distro.nixosModules.hardware-dual-rtx5090
    ./hardware-configuration.nix
  ];

  distro.llm-server.firewallInterfaces = [ "wg0" ];
}
```

Defaults to latest kernel, NVIDIA open driver, persistence daemon, CUDA capability `12.0`, and NVIDIA Container Toolkit/CDI.

## Packages

- `packages.<system>.ask-local` — llama.cpp wrapper for a small local model; supports one-shot, grammar-constrained, n-gram lookup, and OpenAI-compatible server mode.
- `packages.<system>.llm-router` — OpenAI-compatible request-shape router. Short/no-tool chat requests go to `LLM_ROUTER_LOCAL`; larger/tool requests go to `LLM_ROUTER_UPSTREAM`.

## Development

```sh
nix fmt -- --ci
nix flake check --no-build --all-systems
nix build .#llm-router
nix build .#checks.x86_64-linux.llama-swap
```

The `llama-swap` VM test downloads pinned GGUF models and can be large/slow; use `--no-build` for fast evaluation-only checks.
