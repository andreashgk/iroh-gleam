{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  packages = with pkgs; [
    erlang
    cargo
    clang
    clippy
    gleam
    mold
    rebar3
    rust-analyzer
    rustc
    rustfmt
  ];

  shellHook = ''
    export RUSTFLAGS="-C link-arg=-fuse-ld=mold"
  '';
}
