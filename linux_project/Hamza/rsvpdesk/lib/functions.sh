#!/usr/bin/env bash
# L37 Event RSVP Manager | functions for the 5 required features
DATA='data/guests.csv'
LOG='logs/activity.log'
CONFIG='data/event.conf'

log() {
  mkdir -p logs
  printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"
}

check_data() {
  if [[ ! -f "$DATA" ]]; then
    echo "ERROR: Guest file missing: $DATA" >&2
    return 1
  fi
  if [[ "$(head -n 1 "$DATA")" != 'name,email,rsvp,food_pref' ]]; then
    echo 'ERROR: Unexpected guests.csv header.' >&2
    return 1
  fi
}

show_help() {
  cat <<'HELP'
L37 - Event RSVP Manager (Bash)
Usage:
  ./main.sh             Open the interactive menu
  ./main.sh --status    Print RSVP counts
  ./main.sh --backup    Create a tar.gz backup of guest data
  ./main.sh --cron      Write reports/rsvp_status.txt (schedule daily at 18:00)
  ./main.sh --test      Run tests on an isolated temporary copy
  ./main.sh --help      Show help
The sample guest list is fictional. Configure event details in data/event.conf.
HELP
}

valid_name() {
  [[ -n "${1//[[:space:]]/}" && "$1" != *','* && "$1" != *$'\n'* && "$1" != *$'\r'* && ${#1} -le 80 ]]
}

valid_email() {
  [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ && ${#1} -le 120 ]]
}

valid_rsvp() { [[ "$1" == yes || "$1" == no || "$1" == maybe ]]; }
valid_food() { [[ "$1" == veg || "$1" == nonveg || "$1" == jain || "$1" == none ]]; }
normalize() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

email_exists() {
  local email="$1"
  awk -F, -v key="$email" 'NR>1 && tolower($2)==tolower(key) { found=1; exit } END {exit !found}' "$DATA"
}

# FEATURE 1: Add a guest. CSV values are validated to prevent delimiter injection.
feature_1() {
  check_data || return 1
  local name email rsvp food
  echo '== Add a guest =='
  IFS= read -r -p 'Name: ' name || return 1
  if ! valid_name "$name"; then echo 'Invalid name (must be nonempty, <=80 chars, without commas).'; return 1; fi
  IFS= read -r -p 'Email: ' email || return 1
  email="$(normalize "$email")"
  if ! valid_email "$email"; then echo 'Invalid email address.'; return 1; fi
  if email_exists "$email"; then echo 'Guest with this email already exists.'; return 1; fi
  IFS= read -r -p 'RSVP (yes/no/maybe): ' rsvp || return 1
  rsvp="$(normalize "$rsvp")"
  if ! valid_rsvp "$rsvp"; then echo 'RSVP must be yes, no, or maybe.'; return 1; fi
  IFS= read -r -p 'Food preference (veg/nonveg/jain/none): ' food || return 1
  food="$(normalize "$food")"
  if ! valid_food "$food"; then echo 'Food preference must be veg, nonveg, jain, or none.'; return 1; fi
  printf '%s,%s,%s,%s\n' "$name" "$email" "$rsvp" "$food" >> "$DATA" || return 1
  echo "Guest added: $name ($email)"
  log "Guest added: $email; RSVP=$rsvp; Food=$food"
}

# FEATURE 2: Required RSVP counts using awk and sort/uniq -c.
feature_2() {
  check_data || return 1
  echo '== RSVP status report =='
  local total
  total="$(awk 'END {print NR-1}' "$DATA")"
  printf 'Total guests: %s\n' "$total"
  printf '%-12s %8s\n' 'RSVP' 'COUNT'
  printf '%-12s %8s\n' '------------' '--------'
  for status in yes no maybe; do
    printf '%-12s %8s\n' "$status" "$(awk -F, -v s="$status" 'NR>1 && $3==s {n++} END {print n+0}' "$DATA")"
  done
  echo 'Frequency check (sort | uniq -c):'
  tail -n +2 "$DATA" | cut -d, -f3 | sort | uniq -c
  log 'RSVP summary viewed'
}

# FEATURE 3: Food preferences for all guests and confirmed attendees.
feature_3() {
  check_data || return 1
  echo '== Food preference summary =='
  printf '%-12s %8s %12s\n' 'PREFERENCE' 'ALL' 'RSVP=YES'
  printf '%-12s %8s %12s\n' '------------' '--------' '------------'
  awk -F, '
    NR>1 {all[$4]++; if($3=="yes") confirmed[$4]++}
    END {
      split("veg nonveg jain none", food, " ")
      for(i=1;i<=4;i++) printf "%-12s %8d %12d\n", food[i], all[food[i]]+0, confirmed[food[i]]+0
    }' "$DATA"
  echo 'Breakdown (all guests, sort | uniq -c):'
  tail -n +2 "$DATA" | cut -d, -f4 | sort | uniq -c
  echo 'Catering estimates should use the RSVP=YES column.'
  log 'Food summary viewed'
}

# Read editable text values without executing the configuration as shell code.
load_event() {
  EVENT_NAME='College Fest (Demo)'
  EVENT_DATE='To be announced'
  EVENT_TIME='To be announced'
  EVENT_VENUE='Campus Auditorium'
  EVENT_END_DATE=''
  [[ -f "$CONFIG" ]] || return 0
  local key value
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    value="${value%$'\r'}"
    case "$key" in
      EVENT_NAME) EVENT_NAME="$value" ;;
      EVENT_DATE) EVENT_DATE="$value" ;;
      EVENT_TIME) EVENT_TIME="$value" ;;
      EVENT_VENUE) EVENT_VENUE="$value" ;;
      EVENT_END_DATE) EVENT_END_DATE="$value" ;;
    esac
  done < "$CONFIG"
}

# FEATURE 4: Here-document creates invitations; no emails are sent.
write_invitation() {
  local name="$1" email="$2" rsvp="$3" food="$4" safe out
  safe="$(printf '%s' "$email" | tr -c 'A-Za-z0-9._-' '_')"
  out="invitations/invite_${safe}.txt"
  cat > "$out" <<INVITATION
==================================================
               EVENT INVITATION
==================================================
Dear $name,

You are invited to join us for:
  Event   : $EVENT_NAME
  Date    : $EVENT_DATE
  Time    : $EVENT_TIME
  Venue   : $EVENT_VENUE

Guest email      : $email
Current RSVP     : $rsvp
Food preference  : $food

We look forward to welcoming you!

Warm regards,
College Fest Organising Committee
==================================================
INVITATION
  printf 'Created: %s\n' "$out"
}

feature_4() {
  check_data || return 1
  load_event
  mkdir -p invitations
  local mode wanted name email rsvp food count=0
  echo '== Generate invitation files (here-documents) =='
  echo '1) One guest by email'
  echo '2) Confirmed guests only (RSVP=yes)'
  echo '3) All guests'
  IFS= read -r -p 'Choose invitation scope: ' mode || return 1
  case "$mode" in
    1) IFS= read -r -p 'Email address: ' wanted || return 1
       wanted="$(normalize "$wanted")"; valid_email "$wanted" || { echo 'Invalid email.'; return 1; } ;;
    2|3) ;;
    *) echo 'Invalid scope.'; return 1 ;;
  esac
  while IFS=, read -r name email rsvp food; do
    [[ "$name" == name && "$email" == email ]] && continue
    if [[ "$mode" == 1 && "$email" != "$wanted" ]]; then continue; fi
    if [[ "$mode" == 2 && "$rsvp" != yes ]]; then continue; fi
    write_invitation "$name" "$email" "$rsvp" "$food" || return 1
    ((count+=1))
  done < "$DATA"
  if ((count == 0)); then echo 'No matching guests; no invitations generated.'; return 1; fi
  printf 'Done: %d invitation file(s). These are local text files, not sent emails.\n' "$count"
  log "Generated $count invitation(s) using mode=$mode"
}

# FEATURE 5: Search by guest name or email with grep -iF (literal search).
feature_5() {
  check_data || return 1
  local query matches
  echo '== Search a guest =='
  IFS= read -r -p 'Name or email to search: ' query || return 1
  if [[ -z "${query//[[:space:]]/}" ]]; then echo 'Search cannot be empty.'; return 1; fi
  matches="$(tail -n +2 "$DATA" | grep -iF -- "$query" || true)"
  if [[ -z "$matches" ]]; then echo 'No matching guest found.'; return 0; fi
  printf '%-24s %-35s %-7s %-8s\n' NAME EMAIL RSVP FOOD
  printf '%s\n' "$matches" | awk -F, '{printf "%-24.24s %-35.35s %-7s %-8s\n",$1,$2,$3,$4}'
  log 'Guest search performed'
}

view_data() {
  check_data || return 1
  echo '== Guest list (sorted by name) =='
  printf '%-24s %-35s %-7s %-8s\n' NAME EMAIL RSVP FOOD
  tail -n +2 "$DATA" | sort -t, -k1,1f | awk -F, '{printf "%-24.24s %-35.35s %-7s %-8s\n",$1,$2,$3,$4}'
  log 'Guest list viewed'
}

do_backup() {
  check_data || return 1
  mkdir -p backups
  local filename
  filename="backups/rsvp_$(date '+%Y%m%d_%H%M%S_%N').tar.gz"
  if tar -czf "$filename" data/ invitations/; then
    printf 'Backup saved: %s (%s)\n' "$filename" "$(du -h "$filename" | cut -f1)"
    log "Backup created: $filename"
  else
    echo 'Backup failed.' >&2
    rm -f -- "$filename"
    return 1
  fi
}

view_log() {
  if [[ -s "$LOG" ]]; then tail -n 20 "$LOG"; else echo 'No activity logged yet.'; fi
}

# Extra feature: Update a guest record atomically using awk and mv.
update_guest() {
  check_data || return 1
  local email rsvp food tmp
  IFS= read -r -p 'Existing guest email: ' email || return 1
  email="$(normalize "$email")"
  if ! email_exists "$email"; then echo 'Email not found.'; return 1; fi
  IFS= read -r -p 'New RSVP (yes/no/maybe): ' rsvp || return 1
  rsvp="$(normalize "$rsvp")"
  if ! valid_rsvp "$rsvp"; then echo 'Invalid RSVP.'; return 1; fi
  IFS= read -r -p 'New food preference (veg/nonveg/jain/none): ' food || return 1
  food="$(normalize "$food")"
  if ! valid_food "$food"; then echo 'Invalid food preference.'; return 1; fi
  tmp="$(mktemp 'data/.guests.XXXXXX')" || return 1
  if awk -F, -v OFS=, -v email="$email" -v status="$rsvp" -v food="$food" \
     'NR==1 {print;next} tolower($2)==email {$3=status;$4=food} {print}' "$DATA" > "$tmp"; then
    mv -f -- "$tmp" "$DATA" || { rm -f -- "$tmp"; return 1; }
    echo "Updated $email to RSVP=$rsvp, food=$food"
    log "Updated $email; RSVP=$rsvp; food=$food"
  else
    rm -f -- "$tmp"
    echo 'Update failed.' >&2
    return 1
  fi
}

# Required cron action: latest counts as a report in reports/rsvp_status.txt.
cron_task() {
  check_data || return 1
  load_event
  if [[ -n "$EVENT_END_DATE" ]]; then
    if [[ ! "$EVENT_END_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
       [[ "$(date -d "$EVENT_END_DATE" +%F 2>/dev/null)" != "$EVENT_END_DATE" ]]; then
      echo 'ERROR: EVENT_END_DATE must be a valid YYYY-MM-DD.' >&2
      log 'Cron action rejected: invalid EVENT_END_DATE'
      return 1
    fi
    if [[ "$(date +%F)" > "$EVENT_END_DATE" ]]; then
      echo 'Event end date passed: no new RSVP report generated.'
      log 'Cron skipped: event end date passed'
      return 0
    fi
  fi
  mkdir -p reports logs
  local out='reports/rsvp_status.txt' temp
  temp="$(mktemp 'reports/.rsvp_status.XXXXXX')" || return 1
  if ! awk -F, -v stamp="$(date '+%Y-%m-%d %H:%M:%S')" '
      NR>1 { total++; count[$3]++ }
      END {
        print "RSVP STATUS REPORT - " stamp
        print "=========================================="
        printf "Total guests : %d\n", total+0
        printf "YES          : %d\n", count["yes"]+0
        printf "NO           : %d\n", count["no"]+0
        printf "MAYBE        : %d\n", count["maybe"]+0
      }' "$DATA" > "$temp"; then
    rm -f -- "$temp"
    return 1
  fi
  mv -f -- "$temp" "$out" || return 1
  printf '%s | RSVP report written to %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$out" >> reports/cron_output.txt
  echo "RSVP status saved: $out"
  log 'Scheduled RSVP report generated'
}
