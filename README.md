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
| **2** | Package Cache | Clear APT cache and unused packages |
| **3** | System Logs | Remove old logs (>7 days) |
| **4** | Apache Logs | Clean large web server logs |
| **5** | MySQL Logs | Remove old database logs |
| **6** | Redis Cache | Clear old dump files |
| **7** | User Cache | Clean browser and app caches |
| **8** | Temp Files | Remove temporary files |
| **9** | Snap Cache | Clean snap package cache |
| **10** | VS Code Logs | Remove editor logs and PID files |

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

- `run.sh` - Main cleanup menu
- `unzip_backups.sh` - Interactive backup extractor

## Example

```bash
🧹 PACKAGE CACHE CLEANUP
📁 Found: 1.2GB cache (2847 files)
Continue cleanup? (y/N): y
✅ Freed 374MB of disk space
```