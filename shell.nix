with import <nixpkgs> {};

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    wget      # wget
    qemu      # qemu-img, qemu-system-*
    qemu_kvm
  ];

  hardeningDisable = [ "all" ];
}
