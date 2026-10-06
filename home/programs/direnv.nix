{ pkgs, ... }:

{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;

    # Skip direnv's upstream zsh integration tests — they can hang
    # indefinitely on darwin during checkPhase.
    package = pkgs.direnv.overrideAttrs (_: { doCheck = false; });
  };
}
