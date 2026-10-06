{ username, ... }:

{
  imports = [
    ./packages.nix
    ./runtimes.nix
    ./programs/claude.nix
    ./programs/direnv.nix
    ./programs/fzf.nix
    ./programs/gh.nix
    ./programs/ghostty.nix
    ./programs/git.nix
    ./programs/gpg.nix
    ./programs/iterm2.nix
    ./programs/karabiner.nix
    ./programs/kitty.nix
    ./programs/neovim.nix
    ./programs/tmux.nix
    ./programs/zsh.nix
  ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
