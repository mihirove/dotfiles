{ config, dotfilesPath, ... }:

{
  # claude CLI may write to settings.json (e.g. when adding MCP servers
  # or hooks), so each entry is mkOutOfStoreSymlink to the repo path
  # rather than the readonly nix store.
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/claude/CLAUDE.md";

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/claude/settings.json";

  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/claude/skills";

  home.file.".claude/output-styles".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/claude/output-styles";

  home.file.".claude/hooks".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/claude/hooks";

  home.file.".claude/statusline-command.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/claude/statusline-command.sh";
}
