#!/usr/bin/env bash
# L37 Event RSVP Manager | Main menu and command-line entry points
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
source lib/functions.sh

case "${1:-}" in
  --help)   show_help; exit 0 ;;
  --backup) do_backup; exit $? ;;
  --cron)   cron_task; exit $? ;;
  --status) feature_2; exit $? ;;
  --test)   bash tests/run_tests.sh; exit $? ;;
  "") ;;
  *) echo "Unknown argument: $1"; show_help; exit 2 ;;
esac

while true; do
  printf '\n==========================================\n'
  printf '       EVENT RSVP MANAGER  |  L37\n'
  printf '==========================================\n'
  printf ' 1) Add a guest\n'
  printf ' 2) RSVP counts (yes / no / maybe)\n'
  printf ' 3) Food preference summary\n'
  printf ' 4) Generate invitation files (here-doc)\n'
  printf ' 5) Search a guest\n'
  printf ' 6) View all guests\n'
  printf ' 7) Backup data (tar.gz)\n'
  printf ' 8) View activity log\n'
  printf ' 9) Update RSVP / food preference [extra]\n'
  printf ' 0) Exit\n'
  printf '%s\n' '------------------------------------------'
  if ! IFS= read -r -p 'Enter choice: ' choice; then
    printf '\nInput closed. Goodbye!\n'
    break
  fi
  case "$choice" in
    1) feature_1 ;;
    2) feature_2 ;;
    3) feature_3 ;;
    4) feature_4 ;;
    5) feature_5 ;;
    6) view_data ;;
    7) do_backup ;;
    8) view_log ;;
    9) update_guest ;;
    0) echo 'Goodbye!'; break ;;
    *) echo 'Invalid option. Choose 0-9.' ;;
  esac
done
