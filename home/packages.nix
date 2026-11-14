{ pkgs, ... }:

{
  home.packages = with pkgs; [
    asciinema
    asciinema-agg
    envsubst
    fd
    ghq
    gnupg
    google-cloud-sdk
    jq
    kitty
    lua
    maccy
    prettierd
    pstree
    ripgrep
    tree
    tree-sitter
  ];
}
