# VM-only debug conveniences.
#
# Applied via virtualisation.vmVariant so they only affect builds of
# `system.build.vm` (e.g. `nix build .#test-vm`), not the installed
# system. Adds:
#   - virtio-vga-gl + GTK GL display so niri can render hardware-accelerated
#   - GTK menubar hidden so Alt+letter combos reach the guest compositor
#   - HDA audio with duplex (playback + mic) via host PipeWire
#   - Host↔guest clipboard sharing via spice-vdagent
#   - SSH on host:2222 → guest:22 for runtime inspection
{ pkgs, ... }:
{
  virtualisation.vmVariant = {
    virtualisation.memorySize = 8192;
    virtualisation.cores = 8;

    virtualisation.qemu.options = [
      "-device virtio-vga-gl"
      "-display gtk,gl=on,show-menubar=off"
      "-audiodev pipewire,id=snd0"
      "-device intel-hda"
      "-device hda-duplex,audiodev=snd0"
      # Clipboard sharing between host and guest.
      "-chardev qemu-vdagent,id=vdagent,name=vdagent,clipboard=on"
      "-device virtio-serial"
      "-device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
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
      settings.PermitRootLogin = "yes";
    };

    users.mutableUsers = false;
    users.users.root.initialPassword = "root";

    # Use smallest English-only model for faster transcription in VM.
    distro.voxtype.whisperModel = "tiny.en";
    distro.voxtype.whisperLanguage = "en";

    # Guest-side clipboard agent for host↔guest copy/paste.
    services.spice-vdagentd.enable = true;
    systemd.user.services.spice-vdagent = {
      description = "Spice vdagent user session agent";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent -x";
      };
      wantedBy = [ "graphical-session.target" ];
    };
  };
}
