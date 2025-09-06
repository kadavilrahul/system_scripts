#!/bin/bash

# System Cleanup Script
# Interactive menu system for system maintenance and cleanup operations

LOG_FILE="/var/log/system-cleanup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$DATE] $1" | tee -a "$LOG_FILE"
}

confirm_action() {
    echo -n "$1 (y/N): "
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

check_folder_size() {
    local folder="$1"
    local description="$2"
    
    if [ -d "$folder" ]; then
        local size=$(du -sh "$folder" 2>/dev/null | cut -f1)
        local count=$(find "$folder" -type f 2>/dev/null | wc -l)
        echo "📁 $description:"
        echo "   Size: $size"
        echo "   Files: $count"
        return 0
    else
        echo "📁 $description: Directory not found"
        return 1
    fi
}

check_and_handle_locks() {
    local lock_desc="$1"
    
    # Check for APT locks
    if pgrep -x apt > /dev/null || pgrep -x apt-get > /dev/null || pgrep -x dpkg > /dev/null; then
        echo "⚠️  APT process is running. Waiting for it to complete..."
        while pgrep -x apt > /dev/null || pgrep -x apt-get > /dev/null || pgrep -x dpkg > /dev/null; do
            sleep 2
            echo -n "."
        done
        echo " Done."
    fi
    
    # Check for dpkg lock files
    if [ -f /var/lib/dpkg/lock-frontend ] || [ -f /var/lib/apt/lists/lock ] || [ -f /var/cache/apt/archives/lock ]; then
        echo "🔒 Package manager locks detected. Attempting to clear..."
        
        # Kill any hanging processes
        killall apt apt-get dpkg 2>/dev/null || true
        
        # Remove lock files if they exist
        rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
        rm -f /var/lib/apt/lists/lock 2>/dev/null || true  
        rm -f /var/cache/apt/archives/lock 2>/dev/null || true
        
        # Fix broken packages if needed
        dpkg --configure -a 2>/dev/null || true
        
        echo "✅ Lock files cleared."
    fi
    
    # Check for MySQL locks if doing MySQL cleanup
    if [[ "$lock_desc" == *"MySQL"* ]] && systemctl is-active --quiet mysql; then
        if mysqladmin ping 2>/dev/null | grep -q "alive"; then
            echo "✅ MySQL is responding normally"
        else
            echo "⚠️  MySQL appears locked. Attempting to restart..."
            systemctl restart mysql 2>/dev/null || true
            sleep 3
        fi
    fi
}

show_cleanup_summary() {
    local operation="$1"
    local before_size="$2"
    local after_size="$3"
    
    echo ""
    echo "📊 CLEANUP SUMMARY for $operation:"
    echo "   Before: $before_size"
    echo "   After:  $after_size"
    
    # Calculate space freed if possible
    if command -v numfmt >/dev/null 2>&1; then
        local before_bytes=$(echo "$before_size" | numfmt --from=iec 2>/dev/null || echo "0")
        local after_bytes=$(echo "$after_size" | numfmt --from=iec 2>/dev/null || echo "0") 
        local freed_bytes=$((before_bytes - after_bytes))
        if [ $freed_bytes -gt 0 ]; then
            local freed_human=$(numfmt --to=iec $freed_bytes 2>/dev/null || echo "$freed_bytes bytes")
            echo "   Freed:  $freed_human"
        fi
    fi
    echo ""
}

show_menu() {
    clear
    echo "                             MENU"
    echo "========================================================================================"
    echo "1)  Unzip Website Backups      - Extract all backup files from /website_backups"
    echo "2)  System Monitor             - Display disk usage, directories, logs and status"
    echo "3)  Package Cache Cleanup      - Clean apt cache and remove unused packages"
    echo "4)  Log Files Cleanup          - Clean and rotate system log files"
    echo "5)  Apache Logs Cleanup        - Clean and truncate Apache log files"
    echo "6)  MySQL Cleanup              - Clean MySQL binary logs and optimize"
    echo "7)  Redis Cleanup              - Clean old Redis dump files"
    echo "8)  User Cache Cleanup         - Clean user cache directories"
    echo "9)  Temporary Files Cleanup    - Clean /tmp and /var/tmp directories"
    echo "10) Snap Cache Cleanup         - Remove disabled snap packages"
    echo "11) VS Code Server Cleanup     - Clean old VS Code server files"
    echo "0)  Exit"
    echo "========================================================================================"
    echo -n "Please select an option (0-11): "
}



package_cleanup() {
    echo "🧹 PACKAGE CACHE CLEANUP"
    echo "========================================"
    
    # Check and handle any locks first
    check_and_handle_locks "Package management"
    
    # Show current sizes
    check_folder_size "/var/cache/apt/archives" "APT Cache"
    check_folder_size "/var/lib/apt/lists" "APT Lists"
    
    # Show packages that will be removed
    echo ""
    echo "📦 Packages that will be auto-removed:"
    apt list --installed | grep -E "(rc|linux-image|linux-headers)" | head -10 2>/dev/null || echo "   No packages to auto-remove found"
    
    local before_apt_size=$(du -sh /var/cache/apt 2>/dev/null | cut -f1 || echo "0")
    
    if ! confirm_action "This will clean package cache and remove unused packages. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    echo ""
    echo "🔄 Cleaning package cache..."
    log "Running package cleanup..."
    
    # Clean with verbose output
    apt autoremove -y 2>&1 | tee -a "$LOG_FILE"
    apt autoclean 2>&1 | tee -a "$LOG_FILE" 
    
    # Update package database
    apt update -qq 2>/dev/null || true
    
    echo ""
    echo "✅ Package cleanup completed!"
    
    # Show results
    local after_apt_size=$(du -sh /var/cache/apt 2>/dev/null | cut -f1 || echo "0")
    show_cleanup_summary "Package Cache" "$before_apt_size" "$after_apt_size"
    
    read -p "Press Enter to continue..."
}

logs_cleanup() {
    echo "📄 LOG FILES CLEANUP"
    echo "========================================"
    
    # Show current log sizes
    check_folder_size "/var/log" "System Logs"
    
    # Show journal size
    local journal_size=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMGT]B' | tail -1 || echo "Unknown")
    echo "📔 Systemd Journal: $journal_size"
    
    # Show largest log files
    echo ""
    echo "📊 Largest log files:"
    find /var/log -name "*.log" -o -name "*.gz" -o -name "*.1" | xargs ls -lh 2>/dev/null | sort -k5 -hr | head -5 | while read -r line; do
        echo "   $line"
    done
    
    local before_size=$(du -sh /var/log 2>/dev/null | cut -f1 || echo "0")
    
    if ! confirm_action "This will clean and rotate system log files. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    echo ""
    echo "🔄 Cleaning system logs..."
    log "Running log cleanup..."
    
    # Clean journal logs
    journalctl --vacuum-time=7d 2>&1 | tee -a "$LOG_FILE"
    
    # Clean old log files
    find /var/log -name "*.log" -type f -mtime +7 -delete 2>/dev/null
    find /var/log -name "*.gz" -type f -mtime +7 -delete 2>/dev/null  
    find /var/log -name "*.1" -type f -mtime +3 -delete 2>/dev/null
    find /var/log -name "*.old" -type f -delete 2>/dev/null
    
    echo "✅ Log cleanup completed!"
    
    # Show results
    local after_size=$(du -sh /var/log 2>/dev/null | cut -f1 || echo "0")
    local after_journal=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMGT]B' | tail -1 || echo "Unknown")
    show_cleanup_summary "System Logs" "$before_size" "$after_size"
    echo "📔 Journal size after cleanup: $after_journal"
    
    read -p "Press Enter to continue..."
}

apache_cleanup() {
    echo "🌐 APACHE LOGS CLEANUP"
    echo "========================================"
    
    if [ ! -d "/var/log/apache2" ]; then
        echo "❌ Apache log directory not found."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Show current Apache log sizes
    check_folder_size "/var/log/apache2" "Apache Logs"
    
    # Show large log files
    echo ""
    echo "📊 Large Apache log files (>10MB):"
    find /var/log/apache2 -name "*.log" -size +10M -exec ls -lh {} \; 2>/dev/null | while read -r line; do
        echo "   $line"
    done
    
    local before_size=$(du -sh /var/log/apache2 2>/dev/null | cut -f1 || echo "0")
    
    if ! confirm_action "This will clean and truncate Apache log files. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    echo ""
    echo "🔄 Cleaning Apache logs..."
    log "Running Apache log cleanup..."
    
    # Truncate large current logs
    find /var/log/apache2 -name "*.log" -size +10M -exec truncate -s 0 {} \; 2>/dev/null || true
    echo "   ✅ Truncated large current log files"
    
    # Remove old compressed logs
    find /var/log/apache2 -name "*.log.gz" -mtime +3 -delete 2>/dev/null || true
    find /var/log/apache2 -name "*.log.*" -mtime +3 -delete 2>/dev/null || true
    echo "   ✅ Removed old compressed logs"
    
    # Reload Apache to reinitialize logs
    if systemctl reload apache2 2>/dev/null; then
        echo "   ✅ Apache reloaded successfully"
    else
        echo "   ⚠️  Apache reload failed (service may not be running)"
    fi
    
    echo "✅ Apache log cleanup completed!"
    
    # Show results
    local after_size=$(du -sh /var/log/apache2 2>/dev/null | cut -f1 || echo "0")
    show_cleanup_summary "Apache Logs" "$before_size" "$after_size"
    
    read -p "Press Enter to continue..."
}

mysql_cleanup() {
    echo "🗄️  MYSQL CLEANUP"
    echo "========================================"
    
    if ! systemctl is-active --quiet mysql; then
        echo "❌ MySQL service is not running."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Check and handle MySQL locks
    check_and_handle_locks "MySQL"
    
    # Show current MySQL data size
    check_folder_size "/var/lib/mysql" "MySQL Data Directory"
    
    # Show binary log information
    echo ""
    echo "📊 MySQL Binary Logs:"
    mysql -e "SHOW BINARY LOGS;" 2>/dev/null | head -10 || echo "   Unable to retrieve binary log info"
    
    if ! confirm_action "This will clean MySQL binary logs and optimize databases. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    echo ""
    echo "🔄 Cleaning MySQL..."
    log "Running MySQL cleanup..."
    
    # Purge old binary logs
    mysql -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);" 2>/dev/null || true
    echo "   ✅ Purged binary logs older than 7 days"
    
    # Flush logs
    mysql -e "FLUSH LOGS;" 2>/dev/null || true
    echo "   ✅ Flushed current logs"
    
    # Optimize tables (optional - can be time consuming)
    echo "   🔧 Running table optimization..."
    mysql -e "SELECT table_schema as 'Database', table_name as 'Table', ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys') ORDER BY (data_length + index_length) DESC LIMIT 5;" 2>/dev/null || true
    
    echo "✅ MySQL cleanup completed!"
    
    read -p "Press Enter to continue..."
}

redis_cleanup() {
    echo "🔴 REDIS CLEANUP"
    echo "========================================"
    
    if ! systemctl is-active --quiet redis; then
        echo "❌ Redis service is not running."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Show current Redis data size
    check_folder_size "/var/lib/redis" "Redis Data Directory"
    
    # Show dump files to be cleaned
    echo ""
    echo "🗑️  Old dump files to be removed:"
    find /var/lib/redis -name "dump.rdb.*" -type f -mtime +7 2>/dev/null | while read -r file; do
        local size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}')
        echo "   $file ($size)"
    done || echo "   No old dump files found"
    
    local before_size=$(du -sh /var/lib/redis 2>/dev/null | cut -f1 || echo "0")
    
    if ! confirm_action "This will clean old Redis dump files. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    echo ""
    echo "🔄 Cleaning Redis dumps..."
    log "Running Redis cleanup..."
    
    local removed_count=$(find /var/lib/redis -name "dump.rdb.*" -type f -mtime +7 -delete -print 2>/dev/null | wc -l)
    echo "   ✅ Removed $removed_count old dump files"
    
    echo "✅ Redis cleanup completed!"
    
    # Show results
    local after_size=$(du -sh /var/lib/redis 2>/dev/null | cut -f1 || echo "0")
    show_cleanup_summary "Redis Data" "$before_size" "$after_size"
    
    read -p "Press Enter to continue..."
}

user_cache_cleanup() {
    echo "👤 USER CACHE CLEANUP"
    echo "========================================"
    
    # Show current cache sizes
    check_folder_size "/root/.cache" "Root User Cache"
    
    # Find and show user cache directories
    echo ""
    echo "🏠 Home directory caches:"
    find /home -name ".cache" -type d 2>/dev/null | while read -r cache_dir; do
        if [ -d "$cache_dir" ]; then
            local size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
            echo "   $cache_dir: $size"
        fi
    done
    
    local before_size=$(du -sh /root/.cache 2>/dev/null | cut -f1 || echo "0")
    
    if ! confirm_action "This will clean user cache directories. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    echo ""
    echo "🔄 Cleaning user cache directories..."
    log "Running user cache cleanup..."
    
    # Clean root cache
    if [ -d "/root/.cache" ]; then
        rm -rf /root/.cache/* 2>/dev/null || true
        echo "   ✅ Cleaned root user cache"
    fi
    
    # Clean home directory caches  
    find /home -name ".cache" -type d 2>/dev/null | while read -r cache_dir; do
        if [ -d "$cache_dir" ]; then
            rm -rf "$cache_dir"/* 2>/dev/null || true
            echo "   ✅ Cleaned $(dirname "$cache_dir")'s cache"
        fi
    done
    
    echo "✅ User cache cleanup completed!"
    
    # Show results
    local after_size=$(du -sh /root/.cache 2>/dev/null | cut -f1 || echo "0")
    show_cleanup_summary "User Caches" "$before_size" "$after_size"
    
    read -p "Press Enter to continue..."
}

temp_files_cleanup() {
    echo "🗂️  TEMPORARY FILES CLEANUP"  
    echo "========================================"
    
    # Show current temp sizes
    check_folder_size "/tmp" "Temporary Files (/tmp)"
    check_folder_size "/var/tmp" "Persistent Temp Files (/var/tmp)"
    
    # Show what files will be cleaned
    echo ""
    echo "🧹 Files to be cleaned:"
    local tmp_count=$(find /tmp -type f -atime +7 2>/dev/null | wc -l)
    local var_tmp_count=$(find /var/tmp -type f -atime +30 2>/dev/null | wc -l)
    echo "   /tmp: $tmp_count files older than 7 days"
    echo "   /var/tmp: $var_tmp_count files older than 30 days"
    
    local before_tmp_size=$(du -sh /tmp 2>/dev/null | cut -f1 || echo "0")
    local before_var_tmp_size=$(du -sh /var/tmp 2>/dev/null | cut -f1 || echo "0")
    
    if ! confirm_action "This will clean temporary files from /tmp and /var/tmp. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    echo ""
    echo "🔄 Cleaning temporary files..."
    log "Running temporary files cleanup..."
    
    # Clean /tmp files older than 7 days
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    echo "   ✅ Cleaned /tmp (files older than 7 days)"
    
    # Clean /var/tmp files older than 30 days  
    find /var/tmp -type f -atime +30 -delete 2>/dev/null || true
    echo "   ✅ Cleaned /var/tmp (files older than 30 days)"
    
    echo "✅ Temporary files cleanup completed!"
    
    # Show results
    local after_tmp_size=$(du -sh /tmp 2>/dev/null | cut -f1 || echo "0")
    local after_var_tmp_size=$(du -sh /var/tmp 2>/dev/null | cut -f1 || echo "0")
    show_cleanup_summary "/tmp" "$before_tmp_size" "$after_tmp_size"
    show_cleanup_summary "/var/tmp" "$before_var_tmp_size" "$after_var_tmp_size"
    
    read -p "Press Enter to continue..."
}

snap_cleanup() {
    echo "📦 SNAP CACHE CLEANUP"
    echo "========================================"
    
    if ! command -v snap >/dev/null 2>&1; then
        echo "❌ Snap is not installed on this system."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Show current snap usage
    check_folder_size "/var/lib/snapd/snaps" "Snap Packages"
    
    # Show disabled snaps
    echo ""
    echo "🔄 Disabled snap revisions to be removed:"
    snap list --all | awk '/disabled/{print "   " $1 " (revision " $3 ")"}' || echo "   No disabled snaps found"
    
    if ! confirm_action "This will remove disabled snap packages. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    local before_size=$(du -sh /var/lib/snapd/snaps 2>/dev/null | cut -f1 || echo "0")
    
    echo ""
    echo "🔄 Cleaning snap cache..."
    log "Running snap cleanup..."
    
    snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
        echo "   🗑️  Removing $snapname revision $revision..."
        snap remove "$snapname" --revision="$revision" 2>/dev/null || true
    done
    
    echo "✅ Snap cleanup completed!"
    
    # Show results
    local after_size=$(du -sh /var/lib/snapd/snaps 2>/dev/null | cut -f1 || echo "0")
    show_cleanup_summary "Snap Packages" "$before_size" "$after_size"
    
    read -p "Press Enter to continue..."
}

vscode_cleanup() {
    echo "💻 VS CODE SERVER CLEANUP"
    echo "========================================"
    
    if [ ! -d "/root/.vscode-server" ]; then
        echo "❌ VS Code server directory not found."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Show current VS Code server size
    check_folder_size "/root/.vscode-server" "VS Code Server Directory"
    
    # Show files to be cleaned
    echo ""
    echo "🧹 Files to be cleaned:"
    local log_count=$(find /root/.vscode-server -name "*.log" -mtime +30 2>/dev/null | wc -l)
    local pid_count=$(find /root/.vscode-server -name "*.pid" 2>/dev/null | wc -l)
    echo "   Log files (>30 days): $log_count"
    echo "   PID files: $pid_count"
    
    local before_size=$(du -sh /root/.vscode-server 2>/dev/null | cut -f1 || echo "0")
    
    if ! confirm_action "This will clean old VS Code server files. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    echo ""
    echo "🔄 Cleaning VS Code server files..."
    log "Running VS Code cleanup..."
    
    # Clean old log files
    find /root/.vscode-server -name "*.log" -mtime +30 -delete 2>/dev/null || true
    echo "   ✅ Removed old log files"
    
    # Clean PID files
    find /root/.vscode-server -name "*.pid" -delete 2>/dev/null || true
    echo "   ✅ Removed PID files"
    
    echo "✅ VS Code cleanup completed!"
    
    # Show results
    local after_size=$(du -sh /root/.vscode-server 2>/dev/null | cut -f1 || echo "0")
    show_cleanup_summary "VS Code Server" "$before_size" "$after_size"
    
    read -p "Press Enter to continue..."
}

unzip_backups() {
    if ! confirm_action "This will run the website backup unzip script. Continue?"; then
        echo "Operation cancelled."
        return
    fi
    
    echo "Running website backup unzip script..."
    /system_cleanup/unzip_backups.sh
    read -p "Press Enter to continue..."
}

system_monitor() {
    echo "🖥️  SYSTEM MONITOR"
    echo "========================================"
    
    # Disk Usage
    echo "📊 DISK USAGE:"
    df -h
    echo ""
    echo "Disk usage by filesystem:"
    df -h --type=ext4 --type=xfs --type=btrfs 2>/dev/null || df -h
    echo ""
    
    # Largest Directories
    echo "📁 LARGEST DIRECTORIES (>1GB):"
    echo "Directories in /root above 1GB:"
    du -sh /root/* 2>/dev/null | awk '$1 ~ /[0-9]+(\.[0-9]+)?G/ && $1 !~ /^0\.[0-9]G/' | sort -hr
    echo ""
    echo "Directories in /var above 1GB:"
    du -sh /var/* 2>/dev/null | awk '$1 ~ /[0-9]+(\.[0-9]+)?G/ && $1 !~ /^0\.[0-9]G/' | sort -hr
    echo ""
    
    # System Status
    echo "⚙️  SYSTEM SERVICES STATUS:"
    echo "Apache2: $(systemctl is-active apache2 2>/dev/null || echo 'not installed')"
    echo "MySQL:   $(systemctl is-active mysql 2>/dev/null || echo 'not installed')"
    echo "Redis:   $(systemctl is-active redis 2>/dev/null || echo 'not installed')"
    echo "SSH:     $(systemctl is-active ssh 2>/dev/null || echo 'not installed')"
    echo ""
    echo "System Load:"
    uptime
    echo ""
    echo "Memory Usage:"
    free -h
    echo ""
    
    # Cleanup Logs
    echo "📄 RECENT CLEANUP LOGS:"
    echo "========================================"
    tail -20 "$LOG_FILE" 2>/dev/null || echo "No cleanup logs found."
    echo "========================================"
    
    read -p "Press Enter to continue..."
}

# Main menu loop
while true; do
    show_menu
    read -r choice
    
    case $choice in
        1)
            unzip_backups
            ;;
        2)
            system_monitor
            ;;
        3)
            package_cleanup
            ;;
        4)
            logs_cleanup
            ;;
        5)
            apache_cleanup
            ;;
        6)
            mysql_cleanup
            ;;
        7)
            redis_cleanup
            ;;
        8)
            user_cache_cleanup
            ;;
        9)
            temp_files_cleanup
            ;;
        10)
            snap_cleanup
            ;;
        11)
            vscode_cleanup
            ;;
        0)
            echo "Exiting system cleanup menu."
            exit 0
            ;;
        *)
            echo "Invalid option. Please select 0-11."
            read -p "Press Enter to continue..."
            ;;
    esac
done
