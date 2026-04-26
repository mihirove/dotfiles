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
