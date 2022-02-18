with import <nixpkgs> {};

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    wget      # wget
    qemu      # qemu-img, qemu-system-*
    pkg-config
    pcre.dev
  ];

  hardeningDisable = [ "all" ];
}
