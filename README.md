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

✨ **Interactive Menu** - Easy-to-use cleanup options with previews  
🗂️ **Backup Extraction** - Smart unzip tool for website backups  
🔒 **Safe Operations** - Always asks before deleting anything  
📊 **Detailed Reports** - Shows exactly how much space you'll save  

## Quick Start

```bash
sudo ./run.sh
```

## What It Cleans

| Option | Target | Description |
|--------|--------|-------------|
| **1** | Website Backups | Extract and manage backup archives |
| **2** | System Monitor | Display disk usage, directories, logs and status |
| **3** | Package Cache | Clear APT cache and unused packages |
| **4** | System Logs | Remove old logs (>7 days) |
| **5** | Apache Logs | Clean large web server logs |
| **6** | MySQL Logs | Remove old database logs |
| **7** | Redis Cache | Clear old dump files |
| **8** | User Cache | Clean browser and app caches |
| **9** | Temp Files | Remove temporary files |
| **10** | Snap Cache | Clean snap package cache |
| **11** | VS Code Logs | Remove editor logs and PID files |
| **12** | Git Permissions | Fix permissions for all Git repositories |

## Safety First

- ✅ **Previews everything** before deletion
- ✅ **Asks for confirmation** on every action  
- ✅ **Only removes** logs, cache, and temp files
- ✅ **Logs all operations** to `/var/log/system-cleanup.log`

## Requirements

- Linux system with bash
- Root/sudo access
- Optional services: Apache, MySQL, Redis

## Scripts

- `run.sh` - Main cleanup menu with interactive options
- `unzip_backups.sh` - Interactive backup extractor for website archives
- `fix_git_permissions.sh` - Comprehensive Git repository permission fixer

## Examples

### Package Cleanup
```bash
🧹 PACKAGE CACHE CLEANUP
📁 Found: 1.2GB cache (2847 files)
Continue cleanup? (y/N): y
✅ Freed 374MB of disk space
```

### Git Permissions Fix
```bash
🔧 GIT PERMISSIONS FIX
📊 Found 5 Git repositories in '/home/user/projects'
Continue permissions fix? (y/N): y
✅ Fixed permissions for 5 repositories
```

## Git Permissions Fixer

The `fix_git_permissions.sh` script is a comprehensive tool designed for root-based code execution environments that fixes Git repository permissions and ownership issues.

### Features:
- 🔍 **Auto-discovery** - Finds all Git repositories in specified directory and subdirectories
- 🛡️ **Root ownership** - Sets proper root:root ownership for entire repositories
- 📁 **Git structure** - Fixes `.git` directory permissions (objects, refs, hooks, logs, etc.)
- 🔧 **Working directory** - Sets appropriate permissions for scripts and files
- ✅ **Git verification** - Tests Git operations and adds safe.directory if needed
- 📊 **Detailed reporting** - Shows progress and results for each repository

### Usage:
```bash
# Fix permissions in current directory
sudo ./fix_git_permissions.sh

# Fix permissions in specific directory
sudo ./fix_git_permissions.sh /path/to/projects

# Run via main menu (option 12)
sudo ./run.sh
```

### Safety Features:
- Requires root access for security
- Non-destructive operations
- Handles Git ownership issues automatically
- Provides detailed progress feedback
- Safe to run multiple times