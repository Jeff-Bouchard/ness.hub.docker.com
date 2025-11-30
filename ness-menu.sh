#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_header() {
  cat <<'EOF'

  _   _                            __  __                  
 | \ | |                          |  \/  |                 
 |  \| | ___  ___ ___ _ __   ___  | \  / | ___ _ __  _   _ 
 | . ` |/ _ \/ __/ _ \ '_ \ / _ \ | |\/| |/ _ \ '_ \| | | |
 | |\  |  __/ (_|  __/ | | |  __/ | |  | |  __/ | | | |_| |
 |_| \_|\___|\___\___|_| |_|\___| |_|  |_|\___|_| |_|\__,_|

            unified launcher for Ness menus
EOF
}

run_1ness_menu() {
  if [ -x "$SCRIPT_DIR/1ness-menu.sh" ]; then
    "$SCRIPT_DIR/1ness-menu.sh"
  elif [ -f "$SCRIPT_DIR/1ness-menu.sh" ]; then
    bash "$SCRIPT_DIR/1ness-menu.sh"
  else
    echo "1ness-menu.sh not found next to this launcher."
    return 1
  fi
}

run_v2_menu() {
  if [ -x "$SCRIPT_DIR/2ness-menu-v2.sh" ]; then
    "$SCRIPT_DIR/2ness-menu-v2.sh"
  elif [ -f "$SCRIPT_DIR/2ness-menu-v2.sh" ]; then
    bash "$SCRIPT_DIR/2ness-menu-v2.sh"
  else
    echo "2ness-menu-v2.sh not found next to this launcher."
    return 1
  fi
}

run_v3_menu() {
  if [ -x "$SCRIPT_DIR/menu-v3.sh" ]; then
    "$SCRIPT_DIR/menu-v3.sh"
  elif [ -f "$SCRIPT_DIR/menu-v3.sh" ]; then
    bash "$SCRIPT_DIR/menu-v3.sh"
  else
    echo "menu-v3.sh not found next to this launcher."
    return 1
  fi
}

run_v4_bridge() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is not installed or not in PATH."
    echo "menu-v4.1 bridge requires python3 to run."
    return 1
  fi

  local script="$SCRIPT_DIR/menu-v4.1.py"
  if [ ! -f "$script" ]; then
    echo "menu-v4.1.py not found next to this launcher."
    return 1
  fi

  echo
  echo "Starting menu-v4.1 HTTP bridge on http://127.0.0.1:8085/api/menu"
  echo "You can open one of these dashboards in a browser and point it at that endpoint:"
  echo "  - $SCRIPT_DIR/menu-v4.html"
  echo "  - $SCRIPT_DIR/ness-menu-v3.html"
  echo "  - $SCRIPT_DIR/ness-menu-v3-FR.html"
  echo
  echo "Press Ctrl+C to stop the bridge."
  echo

  python3 "$script" 8085
}

show_html_paths() {
  echo
  echo "HTML dashboards (open manually in a browser):"
  echo "  - $SCRIPT_DIR/menu-v4.html (Menu V4 dashboard)"
  echo "  - $SCRIPT_DIR/ness-menu-v3.html (Menu V3 dashboard, EN)"
  echo "  - $SCRIPT_DIR/ness-menu-v3-FR.html (Menu V3 dashboard, FR)"
  echo
}

main_menu() {
  while true; do
    clear
    print_header
    echo
    echo "Select which menu to run:"
    echo "  1) Ness Essential menu (1ness-menu.sh)"
    echo "  2) Ness Menu V2 (2ness-menu-v2.sh)"
    echo "  3) Ness Menu V3 (menu-v3.sh)"
    echo "  4) Start Menu V4 HTTP bridge (menu-v4.1.py)"
    echo "  5) Show HTML dashboard paths (open in browser)"
    echo "  0) Exit"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      1) run_1ness_menu ;;
      2) run_v2_menu ;;
      3) run_v3_menu ;;
      4) run_v4_bridge ;;
      5) show_html_paths ;;
      0) exit 0 ;;
      *) echo "Invalid choice." ;;
    esac
    echo
    read -rp "Press Enter to return to launcher..." _pause || true
  done
}

main_menu
