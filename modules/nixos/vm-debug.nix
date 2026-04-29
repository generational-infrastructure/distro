# VM-only debug conveniences.
#
# Applied via virtualisation.vmVariant so they only affect builds of
# `system.build.vm` (e.g. `nix build .#test-vm`), not the installed
# system. Adds:
#   - virtio-vga-gl + GTK GL display so niri can render hardware-accelerated
#   - GTK menubar hidden so Alt+letter combos reach the guest compositor
#   - SSH on host:2222 → guest:22 for runtime inspection
_:
{
  virtualisation.vmVariant = {
    virtualisation.memorySize = 8192;
    virtualisation.cores = 4;

    virtualisation.qemu.options = [
      "-device virtio-vga-gl"
      "-display gtk,gl=on,show-menubar=off"
    ];

    virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
      settings.PermitRootLogin = "no";
    };
  };
}
