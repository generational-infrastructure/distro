# Builds the test-machine QEMU VM.
# Run: nix build .#test-vm && ./result/bin/run-test-machine-vm
{ inputs, ... }: inputs.self.nixosConfigurations.test-machine.config.system.build.vm
