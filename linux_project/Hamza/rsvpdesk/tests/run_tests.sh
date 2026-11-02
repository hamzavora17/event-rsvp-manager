#!/usr/bin/env bash
# Run in a disposable copy: never modifies the real project's guest list.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
cp -a "$ROOT" "$WORK/rsvpdesk"
cd "$WORK/rsvpdesk"
pass=0
assert() {
  local label="$1" ok="$2"
  if [[ "$ok" == yes ]]; then
    echo "PASS: $label"
    ((pass+=1))
  else
    echo "FAIL: $label" >&2
    exit 1
  fi
}

bash -n main.sh lib/functions.sh
assert 'Bash syntax' yes
rows=$(($(wc -l < data/guests.csv)-1))
[[ $rows -ge 30 ]] && ok=yes || ok=no
assert 'At least 30 fictional guests' "$ok"

output="$(./main.sh --status)"
[[ "$output" == *'Total guests: 36'* && "$output" == *'yes'* && "$output" == *'maybe'* ]] && ok=yes || ok=no
assert 'RSVP status counts' "$ok"

output="$(printf '3\n0\n' | ./main.sh)"
[[ "$output" == *'Food preference summary'* && "$output" == *'RSVP=YES'* ]] && ok=yes || ok=no
assert 'Food preference summary' "$ok"

output="$(printf '1\nDemo Student\ndemo.student@example.com\nyes\nveg\n0\n' | ./main.sh)"
[[ "$output" == *'Guest added'* ]] && grep -qF 'demo.student@example.com,yes,veg' data/guests.csv && ok=yes || ok=no
assert 'Adding a validated guest' "$ok"

output="$(printf '1\nRepeat Student\ndemo.student@example.com\nyes\nveg\n0\n' | ./main.sh)"
[[ "$output" == *'already exists'* ]] && ok=yes || ok=no
assert 'Duplicate email rejected' "$ok"

output="$(printf '1\nBad Student\nnot-an-email\n0\n' | ./main.sh)"
[[ "$output" == *'Invalid email'* ]] && ok=yes || ok=no
assert 'Invalid email rejected' "$ok"

output="$(printf '5\nDemo Student\n0\n' | ./main.sh)"
[[ "$output" == *'demo.student@example.com'* ]] && ok=yes || ok=no
assert 'Guest searching' "$ok"

output="$(printf '4\n1\ndemo.student@example.com\n0\n' | ./main.sh)"
[[ "$output" == *'Done: 1 invitation'* ]] && [[ -f invitations/invite_demo.student_example.com.txt ]] && grep -q 'Dear Demo Student' invitations/invite_demo.student_example.com.txt && ok=yes || ok=no
assert 'Here-document invitation generation' "$ok"

output="$(printf '9\ndemo.student@example.com\nmaybe\njain\n0\n' | ./main.sh)"
grep -qF 'demo.student@example.com,maybe,jain' data/guests.csv && ok=yes || ok=no
assert 'Updating RSVP and food preference' "$ok"

./main.sh --backup > /dev/null
found=(backups/rsvp_*.tar.gz)
[[ -f "${found[0]}" ]] && tar -tzf "${found[0]}" | grep -qF 'data/guests.csv' && ok=yes || ok=no
assert 'Backup archive and contents' "$ok"

./main.sh --cron > /dev/null
[[ -s reports/rsvp_status.txt ]] && grep -q 'Total guests : 37' reports/rsvp_status.txt && ok=yes || ok=no
assert 'Cron report generated' "$ok"

./main.sh --cron >/dev/null
[[ $(grep -c 'Total guests :' reports/rsvp_status.txt) == 1 ]] && ok=yes || ok=no
assert 'Cron overwrites status rather than duplicating counts' "$ok"

printf 'EVENT_END_DATE=2000-01-01\n' >> data/event.conf
output="$(./main.sh --cron)"
[[ "$output" == *'end date passed'* ]] && ok=yes || ok=no
assert 'Cron honors configured event end date' "$ok"

printf '\nALL %d CHECKS PASSED. The original project data was not changed.\n' "$pass"
