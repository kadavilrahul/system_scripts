# System Scripts

An interactive menu-driven system cleanup suite for Linux systems with automated backup extraction, intelligent cache management, and comprehensive disk space cleanup with detailed reporting.

## Installation

### Clone the repository
```bash
git clone https://github.com/kadavilrahul/system_scripts.git
```

### Navigate to directory
```bash
cd system_scripts
```

### Make script executable
```bash
bash run.sh
```

## Features

- **Interactive Menu System**: 14 numbered cleanup options with clear descriptions
- **Website Backup Extraction**: Automatically unzips all backup files from `/website_backups`
- **Pre-Cleanup Analysis**: Shows folder sizes and file counts before each operation
- **Cache Lock Handling**: Intelligent detection and clearing of APT/package manager locks
- **Safe Operations**: User confirmation required for all destructive operations
- **Detailed Reporting**: Shows before/after disk usage with precise space calculations
- **Service-Aware**: Handles Apache, MySQL, Redis, and other services intelligently
- **Real-time Feedback**: Progress indicators and success/failure reporting
- **Comprehensive Logging**: All operations logged to `/var/log/system-cleanup.log`

## Menu Options

### 1. Unzip Website Backups
- Extracts all backup files from `/website_backups` directory
- Supports `.tar.gz`, `.tar.bz2`, `.tar`, and `.zip` formats
- Shows file counts and sizes before extraction
- Extracts directly to `/website_backups` with organized structure

### 2. Package Cache Cleanup
- Shows current APT cache and lists sizes
- Displays packages to be auto-removed
- Removes unused packages (`apt autoremove`)
- Cleans package cache (`apt autoclean`)
- Handles package manager locks automatically

### 3. Log Files Cleanup
- Shows system log directory sizes
- Displays systemd journal size
- Lists largest log files before cleanup
- Removes logs older than 7 days
- Purges journal logs older than 7 days

### 4. Apache Logs Cleanup
- Shows Apache log directory size
- Lists large log files (>10MB)
- Truncates large current logs
- Removes old compressed logs
- Reloads Apache service

### 5. MySQL Cleanup
- Shows MySQL data directory size
- Displays binary log information
- Purges binary logs older than 7 days
- Flushes current logs
- Shows largest database tables

### 6. Redis Cleanup
- Shows Redis data directory size
- Lists old dump files to be removed
- Removes dump files older than 7 days
- Reports cleanup statistics

### 7. User Cache Cleanup
- Shows root user cache size
- Lists all home directory caches
- Cleans root and user cache directories
- Reports space freed per user

### 8. Temporary Files Cleanup
- Shows `/tmp` and `/var/tmp` sizes
- Counts files to be cleaned by age
- Removes `/tmp` files older than 7 days
- Removes `/var/tmp` files older than 30 days

### 9. Snap Cache Cleanup
- Shows snap packages directory size
- Lists disabled snap revisions
- Removes disabled snap packages
- Reports space freed

### 10. VS Code Server Cleanup
- Shows VS Code server directory size
- Lists files to be cleaned
- Removes old log files (>30 days)
- Removes PID files

### 11-14. System Information
- **Disk Usage**: Current disk space usage
- **Largest Directories**: Top space consumers
- **Cleanup Logs**: Recent cleanup log entries
- **System Status**: Service status and system health

## Usage

```bash
# Run with sudo for system-wide cleanup
sudo ./run.sh
```

## Output Example

### Interactive Menu
```
========================================
        SYSTEM CLEANUP MENU
========================================
1)  Unzip Website Backups      - Extract all backup files from /website_backups
2)  Package Cache Cleanup      - Clean apt cache and remove unused packages
3)  Log Files Cleanup          - Clean and rotate system log files
4)  Apache Logs Cleanup        - Clean and truncate Apache log files
5)  MySQL Cleanup              - Clean MySQL binary logs and optimize
6)  Redis Cleanup              - Clean old Redis dump files
7)  User Cache Cleanup         - Clean user cache directories
8)  Temporary Files Cleanup    - Clean /tmp and /var/tmp directories
9)  Snap Cache Cleanup         - Remove disabled snap packages
10) VS Code Server Cleanup     - Clean old VS Code server files
11) Show Disk Usage            - Display current disk space usage
12) Show Largest Directories   - Display largest space consumers
13) View Cleanup Logs          - Display recent cleanup log entries
14) System Status              - Show system services status
0)  Exit
========================================
Please select an option (0-14): 
```

### Cleanup Process Example
```
🧹 PACKAGE CACHE CLEANUP
========================================
✅ APT locks cleared.
📁 APT Cache:
   Size: 1.2G
   Files: 2847

📁 APT Lists:
   Size: 156M
   Files: 1432

📦 Packages that will be auto-removed:
   linux-image-5.15.0-56-generic
   linux-headers-5.15.0-56
   ...

This will clean package cache and remove unused packages. Continue? (y/N): y

🔄 Cleaning package cache...
Reading package lists...
Removing linux-image-5.15.0-56-generic...
   ✅ Package cleanup completed!

📊 CLEANUP SUMMARY for Package Cache:
   Before: 1.2G
   After:  845M
   Freed:  374M
```

## Requirements

- Linux system with bash
- `bc` calculator for precise calculations
- Root/sudo access for system cleanup
- Services: Apache, MySQL, Redis (optional)

## Safety Features

- **User Confirmation**: Every destructive operation requires explicit confirmation
- **Pre-Operation Analysis**: Shows exactly what will be cleaned before proceeding
- **Lock Detection**: Automatically detects and handles package manager locks
- **Service Checks**: Verifies services are running before cleanup
- **Non-destructive**: Only removes logs, cache, and temporary files
- **Error handling**: Continues on errors, doesn't halt execution
- **Comprehensive Logging**: All operations logged with timestamps for audit trail
- **Conservative Defaults**: Keeps recent files, removes only old data

## Scripts Included

### run.sh
Main interactive menu script with 14 cleanup options and system information tools.

### unzip_backups.sh  
Dedicated script for extracting website backups with support for multiple archive formats.

## Configuration

### Customizable Timeouts
- System logs: 7 days (modify `-mtime +7`)
- MySQL binary logs: 7 days (modify `INTERVAL 7 DAY`)
- Temporary files: 7 days for `/tmp`, 30 days for `/var/tmp`
- Apache log size threshold: 10MB (modify `-size +10M`)
- VS Code logs: 30 days (modify `-mtime +30`)
- Redis dumps: 7 days (modify `-mtime +7`)

### Cache Lock Handling
The script automatically:
- Detects running APT/dpkg processes
- Waits for processes to complete
- Removes stale lock files if needed
- Attempts to fix broken packages
- Restarts MySQL if locks are detected

## Automation

The interactive menu is designed for manual use, but individual cleanup functions can be automated by calling them directly:

```bash
# Example: Automate specific cleanup operations
/system_cleanup/unzip_backups.sh  # Extract backups automatically

# Create custom automation script
#!/bin/bash
source /system_cleanup/run.sh
package_cleanup  # Run specific cleanup function
logs_cleanup
```

## Log File

All operations are logged to `/var/log/system-cleanup.log` with timestamps for audit and troubleshooting.

## Warning Threshold

Script warns when disk usage remains above 80% after cleanup, indicating manual intervention may be needed.

## License

MIT License - Feel free to modify and distribute.