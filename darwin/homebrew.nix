{ ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # Applies to both casks and brews; with the full set declared
      # below it makes activation idempotent.
      cleanup = "uninstall";
      # Homebrew >= 5.1 refuses a bare `--cleanup` (it would prompt) and
      # demands one of --force / --force-cleanup / $HOMEBREW_ASK. The pinned
      # nix-darwin still emits the bare flag; drop this once the input is
      # bumped past nix-darwin#1787, which emits --force-cleanup itself.
      extraFlags = [ "--force-cleanup" ];
    };

    brews = [
      # Git worktree manager (phantompane/phantom). Not in nixpkgs.
      # brew pulls node in automatically as a dep, so phantom and the
      # brew bottle's node end up coexisting alongside the nix node.
      "phantom"
    ];

    casks = [
      "fork"
      "orbstack"
    ];
  };
}
