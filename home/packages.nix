{ pkgs, ... }:

{
  home.packages = with pkgs; [
    asciinema
    asciinema-agg
    codex
    envsubst
    fd
    ghq
    gnupg
    google-cloud-sdk
    google-cloud-sql-proxy
    jq
    kitty
    lua
    maccy
    mysql84
    prettierd
    pstree
    ripgrep
    tree
    tree-sitter
  ];
}
