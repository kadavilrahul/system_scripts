# System Cleanup Script

An automated disk space cleanup script for Linux systems that safely removes unnecessary files and logs while providing detailed reporting.

## Installation

### Clone the repository
```bash
git clone https://github.com/kadavilrahul/system_cleanup.git
```

### Navigate to directory
```bash
cd system_cleanup
```

### Make script executable
```bash
bash run.sh
```

## Features

- **Comprehensive Cleanup**: Removes package cache, old logs, temporary files, and more
- **Safe Operations**: Built-in safety checks and error handling
- **Detailed Reporting**: Shows before/after disk usage with `df -h` output
- **Service-Aware**: Handles Apache, MySQL, Redis, and other services intelligently
- **Precise Tracking**: Reports exact space freed in MB/GB
- **Logging**: All operations logged to `/var/log/system-cleanup.log`

## What Gets Cleaned

### Package Management
- Removes unused packages (`apt autoremove`)
- Cleans package cache (`apt autoclean`)
- Removes disabled snap packages

### Log Files
- Truncates large Apache logs (>10MB)
- Cleans system logs older than 7 days
- Purges journal logs older than 7 days
- Removes old MySQL binary logs
- Cleans Redis dump files

### Cache & Temporary Files
- User cache directories (`~/.cache`)
- Temporary files in `/tmp` and `/var/tmp`
- Old VS Code server logs and PID files

### Archive Files
- Removes Google Cloud CLI archive if CLI is already installed
- Other large archive files as configured


# Run with sudo for system-wide cleanup
sudo ./run.sh
```

## Output Example

```
[2025-08-19 10:15:59] Starting system cleanup...
[2025-08-19 10:15:59] Running: df -h /
[2025-08-19 10:15:59] Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       150G   87G   58G  61% /

[2025-08-19 10:15:59] Cleaning package cache...
[2025-08-19 10:15:59] Cleaning user cache directories...
[2025-08-19 10:15:59] Rotating Apache logs...
...

=========================================
CLEANUP SUMMARY:

BEFORE CLEANUP:
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       150G   87G   58G  61% /

AFTER CLEANUP:
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       150G   85G   60G  58% /

✓ Total space cleaned: 2GB (2048MB)
✓ Disk usage: 61% → 58%
=========================================
```

## Requirements

- Linux system with bash
- `bc` calculator for precise calculations
- Root/sudo access for system cleanup
- Services: Apache, MySQL, Redis (optional)

## Safety Features

- **Non-destructive**: Only removes logs, cache, and temporary files
- **Service checks**: Verifies services are running before cleanup
- **Error handling**: Continues on errors, doesn't halt execution
- **Logging**: All operations logged for audit trail
- **Conservative defaults**: Keeps recent files, removes only old data

## Configuration

### Customizable Timeouts
- Logs: 7 days (modify `-mtime +7`)
- MySQL logs: 7 days (modify `INTERVAL 7 DAY`)
- Temporary files: 7-30 days
- Apache log size threshold: 10MB (modify `-size +10M`)

### Optional Cleanup
Development packages cleanup is commented out for safety:
```bash
# Uncomment to remove unused dev packages
# apt autoremove --purge $(dpkg-query -Wf '${Package}\n' | grep -E "(dev|debug|doc)$") -y
```

## Automation

Add to crontab for automatic cleanup:
```bash
# Weekly cleanup every Sunday at 2 AM
0 2 * * 0 /root/system_cleanup/run.sh

# Monthly cleanup on 1st of month
0 2 1 * * /root/system_cleanup/run.sh
```

## Log File

All operations are logged to `/var/log/system-cleanup.log` with timestamps for audit and troubleshooting.

## Warning Threshold

Script warns when disk usage remains above 80% after cleanup, indicating manual intervention may be needed.

## License

MIT License - Feel free to modify and distribute.