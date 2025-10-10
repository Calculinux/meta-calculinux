# Yocto Cache Cleanup - Self-Hosted Runner Setup

This directory contains systemd service and timer units to automatically clean the Yocto build cache on self-hosted GitHub Actions runners.

## Installation

1. **Copy the cleanup script:**
   ```bash
   sudo cp yocto-cache-cleanup.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/yocto-cache-cleanup.sh
   ```

2. **Install systemd units:**
   ```bash
   sudo cp yocto-cache-cleanup.service /etc/systemd/system/
   sudo cp yocto-cache-cleanup.timer /etc/systemd/system/
   ```

3. **Enable and start the timer:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable yocto-cache-cleanup.timer
   sudo systemctl start yocto-cache-cleanup.timer
   ```

4. **Verify the timer is active:**
   ```bash
   sudo systemctl status yocto-cache-cleanup.timer
   sudo systemctl list-timers yocto-cache-cleanup.timer
   ```

## What It Does

The cleanup script runs **every Sunday at 3:00 AM** and:

1. **Removes old sstate-cache entries** (older than 30 days)
2. **Shows cache sizes** before and after cleanup
3. **Checks available disk space**
4. **Performs aggressive cleanup** if disk space is low (<50GB):
   - Removes sstate entries older than 14 days
   - Removes downloads older than 60 days

## Configuration

Edit `/usr/local/bin/yocto-cache-cleanup.sh` to adjust:

- `MAX_AGE_DAYS=30` - How long to keep sstate cache entries
- `MIN_FREE_GB=50` - Threshold for aggressive cleanup
- Cache paths (defaults to `/opt/yocto-cache/calculinux`)

## Manual Execution

To run the cleanup manually:

```bash
sudo systemctl start yocto-cache-cleanup.service
```

Check the logs:

```bash
sudo journalctl -u yocto-cache-cleanup.service -f
```

## Customizing Schedule

Edit the timer to change the schedule:

```bash
sudo systemctl edit yocto-cache-cleanup.timer
```

Example schedules:
- Daily at 2 AM: `OnCalendar=*-*-* 02:00:00`
- Every 3 days: `OnCalendar=*-*-1,4,7,10,13,16,19,22,25,28,31 03:00:00`
- Monthly: `OnCalendar=*-*-01 03:00:00`

After editing:
```bash
sudo systemctl daemon-reload
sudo systemctl restart yocto-cache-cleanup.timer
```

## Monitoring

View cleanup history:
```bash
sudo journalctl -u yocto-cache-cleanup.service --since "1 month ago"
```

Check next scheduled run:
```bash
systemctl list-timers yocto-cache-cleanup.timer
```

## Uninstall

```bash
sudo systemctl stop yocto-cache-cleanup.timer
sudo systemctl disable yocto-cache-cleanup.timer
sudo rm /etc/systemd/system/yocto-cache-cleanup.{service,timer}
sudo rm /usr/local/bin/yocto-cache-cleanup.sh
sudo systemctl daemon-reload
```
