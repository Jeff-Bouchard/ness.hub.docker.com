build_images_menu() {
  while true; do
    echo
    echo -e "${green}Build images menu:${reset}"
    echo "  1) Build ALL images (build-all.sh)"
    echo "  2) Build ALL images (NO CACHE)"
    echo "  3) Build single image"
    echo "  0) Back"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      1) build_all_images ;;
      2) NO_CACHE=1 build-all.sh ;;
      3) build_single_image ;;
      0) return 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}