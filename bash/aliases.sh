# Pi display preference, while preserving management subcommands.
pi() {
  case "$1" in
  install | remove | uninstall | update | list | config | auth | mcp)
    command pi "$@"
    ;;
  *)
    command pi --tui-mode regular --use-theme tomorrow "$@"
    ;;
  esac
}
