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
      # Git worktree manager (phantompane/phantom). The brew bottle ships
      # with a hard-coded `#!/opt/homebrew/opt/node/bin/node` shebang, so
      # moving it to nix would require either upstream support for
      # `#!/usr/bin/env node` or rebuilding it via npm-on-nix.
      "phantom"
    ];

    casks = [
      "fork"
      "orbstack"
    ];
  };
}
