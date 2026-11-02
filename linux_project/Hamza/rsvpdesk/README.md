# L37 — Event RSVP Manager (Linux Shell Scripting)

**Student:** HAMZA VORA | **Roll:** F48 | **Division:** G | **Enrollment:** 24004501210484

## Problem and purpose
Build a menu-driven Bash program for the college fest organising committee to maintain a guest list, track responses (yes/no/maybe), estimate food preferences, generate personalised invitation text files, and search guests. The data is local CSV; no external database or mail service is needed.

## Folder structure

```text
rsvpdesk/
├── main.sh                 # while + case menu and CLI entrypoints
├── lib/functions.sh        # all required features and safety checks
├── data/guests.csv         # 36 fictional sample guests
├── data/event.conf         # edit the event name, venue, and date
├── invitations/            # invitation text files from here-documents
├── reports/                # rsvp_status.txt and cron_output.txt
├── backups/                # timestamped tar.gz archives
├── logs/activity.log       # audit history, populated when used
├── logs/cron.log           # actual cron output (after cron is set up)
├── tests/run_tests.sh      # independent tests, runs on temporary copy
├── CRON_GUIDE.md           # scheduled task instructions
└── README.md
```

## Data file columns
`data/guests.csv` contains **name,email,rsvp,food_pref**. Each guest occupies one row and email is the unique key. Allowed RSVP values: `yes`, `no`, `maybe`. Allowed food values: `veg`, `nonveg`, `jain`, `none`. The 36 initial entries are **fictional** (`@example.com`), not actual participant data. Real guests should consent before their details are entered.

## Run (Ubuntu / WSL)

```bash
cd ~/linux_project/Hamza/rsvpdesk
chmod +x main.sh tests/run_tests.sh
./main.sh
./main.sh --help
./main.sh --status
./main.sh --backup
./main.sh --cron
./tests/run_tests.sh
```

Dependencies: `bash`, GNU `awk`, `grep`, `sort`, `uniq`, `tar`, `date`, `cut`, `tr` and other standard Ubuntu CLI utilities. No `bc`, Python, or database required.

## Required menu features

1. **Add a guest:** asks for name, email, RSVP and food preference; validates values and rejects duplicate emails.
2. **RSVP counts:** shows numbers in `yes/no/maybe` and an additional `sort | uniq -c` frequency check.
3. **Food preference summary:** shows food categories for all guests and among confirmed `yes` attendees (important for catering).
4. **Generate invitations:** uses a Bash `here-document` (`cat <<INVITATION`) to write personal text files for one guest, all confirmed guests, or everyone. **It does not send emails.** Configure `data/event.conf` first.
5. **Search a guest:** case-insensitive, literal name/email search using `grep -iF`.

Also available: view records, data/invitation backup, activity log, and (extra) update an RSVP/food preference. Files are written only inside the project directory.

## Automatic cron task (6 PM)

The script's `--cron` action writes the latest counts to `reports/rsvp_status.txt` and logs execution to `reports/cron_output.txt` and `logs/activity.log`.

```cron
0 18 * * * /bin/bash $HOME/linux_project/Hamza/rsvpdesk/main.sh --cron >> $HOME/linux_project/Hamza/rsvpdesk/logs/cron.log 2>&1
```

**This is NOT installed automatically.** Test `./main.sh --cron`, then follow `CRON_GUIDE.md`. If `EVENT_END_DATE` in `data/event.conf` is a valid `YYYY-MM-DD`, reports are skipped after that date; otherwise remove the crontab entry after the event. WSL must be running and cron service active when the schedule occurs.

## Commands learned

- `while`, `read`, `case`: interactive menu and CSV iteration
- `awk -F,`: count guests and build a formatted report
- `grep -iF`: search a guest without treating search words as regex
- `sort | uniq -c`: frequency distributions
- `cat <<INVITATION`: create a multi-line personalised invitation
- `tar -czf`: create a compressed backup
- `date`: timestamps and cutoff checks
- `crontab`: schedule daily reporting
- `bash -n` and tests: validate implementation

## Test and screenshot checklist

Run the menu and capture screenshots of each of options 1–8; demonstrate invalid input and search, run `./main.sh --cron`, and show `cat reports/rsvp_status.txt` and the `crontab -l` output. Take a **separate, real** screenshot after the 6 PM cron execution and verify `logs/cron.log`. The included report uses developer test outputs and **does not claim a scheduled run was observed**.

## What I learned (example to revise in your own words)

I learned how to build an interactive Linux program using functions, while loops, and case statements. I used CSV files, awk, grep, sort and uniq to process guest information. I learned to create invitation letters with here-documents, store logs, make compressed backups, and test a scheduled cron command. I also practiced validating input and handling missing files safely.

## Important limitations

Simple CSV only: no embedded commas or newlines in guest names. Single-user local program, not a concurrency-safe multi-user database. Invitation files are not sent to recipients. The event details are placeholders until configured. Avoid submitting fictional test guests as real attendees.
