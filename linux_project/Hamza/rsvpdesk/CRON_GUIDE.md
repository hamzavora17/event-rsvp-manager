# Cron demonstration — L37 Event RSVP Manager

1. Open Ubuntu/WSL and install/start cron if needed:

```bash
sudo apt-get update && sudo apt-get install -y cron
sudo service cron start
```

2. Enter your real event details in `data/event.conf`. Set `EVENT_END_DATE=YYYY-MM-DD` to stop generating reports after that date, if known.

3. Test the action manually **before scheduling**:

```bash
cd ~/linux_project/Hamza/rsvpdesk
./main.sh --cron
cat reports/rsvp_status.txt
cat reports/cron_output.txt
```

4. Set up user crontab (`crontab -e`, not `sudo crontab -e`). Add:

```cron
0 18 * * * /bin/bash $HOME/linux_project/Hamza/rsvpdesk/main.sh --cron >> $HOME/linux_project/Hamza/rsvpdesk/logs/cron.log 2>&1
```

The five time fields are minute, hour, day-of-month, month and day-of-week, respectively. `0 18 * * *` means daily at 18:00 in Ubuntu's configured timezone (`date` displays this).

5. Verify installation and after 6 PM capture evidence:

```bash
crontab -l
date
cat ~/linux_project/Hamza/rsvpdesk/logs/cron.log
cat ~/linux_project/Hamza/rsvpdesk/reports/rsvp_status.txt
```

**WSL warning:** Cron runs only while the Linux environment and cron service are actually running. Do not claim a scheduled run occurred until it does.

6. After the event, use `crontab -e` to remove just this RSVP schedule; keep any other project schedules. Never delete your entire crontab if it contains other jobs.
