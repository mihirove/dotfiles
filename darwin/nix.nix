{ lib, username, determinate, ... }:

{
  # Determinate Nix manages the daemon itself, so nix-darwin must yield
  # ownership and skip the nix.* settings below — they would conflict.
  nix.enable = !determinate;

  nix.settings = lib.mkIf (!determinate) {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" username ];
  };

  nix.gc = lib.mkIf (!determinate) {
    automatic = true;
    interval = [{ Weekday = 0; Hour = 3; Minute = 0; }];
    options = "--delete-older-than 30d";
  };

  nix.optimise.automatic = lib.mkIf (!determinate) true;
}
