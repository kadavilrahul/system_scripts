#!/bin/bash

# System Cleanup Script
# Runs automated cleanup to prevent disk space issues

LOG_FILE="/var/log/system-cleanup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$DATE] $1" | tee -a "$LOG_FILE"
}

log "Starting system cleanup..."

# Show initial disk usage
log "Running: df -h /"
INITIAL_DF_OUTPUT=$(df -h /)
log "$INITIAL_DF_OUTPUT"

INITIAL_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
INITIAL_USED_KB=$(df / | awk 'NR==2 {print $3}')
INITIAL_USED_GB=$(echo "scale=1; $INITIAL_USED_KB / 1024 / 1024" | bc)
TOTAL_SPACE_KB=$(df / | awk 'NR==2 {print $2}')
TOTAL_SPACE_GB=$(echo "scale=1; $TOTAL_SPACE_KB / 1024 / 1024" | bc)

# Clean package cache
log "Cleaning package cache..."
apt autoremove -y >> "$LOG_FILE" 2>&1
apt autoclean >> "$LOG_FILE" 2>&1

# Clean user cache directories
log "Cleaning user cache directories..."
rm -rf /root/.cache/* 2>/dev/null || true
find /home -name ".cache" -type d -exec rm -rf {}/* \; 2>/dev/null || true

# Rotate and compress large Apache logs
log "Rotating Apache logs..."
if [ -d "/var/log/apache2" ]; then
    # Truncate current large logs instead of just compressing
    find /var/log/apache2 -name "*.log" -size +10M -exec truncate -s 0 {} \; 2>/dev/null || true
    find /var/log/apache2 -name "*.log.gz" -mtime +3 -delete 2>/dev/null || true
    find /var/log/apache2 -name "*.log.*" -mtime +3 -delete 2>/dev/null || true
    systemctl reload apache2 2>/dev/null || true
fi

# Clean old logs (keep last 7 days for faster cleanup)
log "Cleaning old logs..."
journalctl --vacuum-time=7d >> "$LOG_FILE" 2>&1
find /var/log -name "*.log" -type f -mtime +7 -delete 2>/dev/null
find /var/log -name "*.gz" -type f -mtime +7 -delete 2>/dev/null
find /var/log -name "*.1" -type f -mtime +3 -delete 2>/dev/null
find /var/log -name "*.old" -type f -delete 2>/dev/null

# MySQL cleanup (if MySQL is running)
if systemctl is-active --quiet mysql; then
    log "Cleaning MySQL logs..."
    mysql -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);" 2>/dev/null || true
    mysql -e "FLUSH LOGS;" 2>/dev/null || true
fi

# Redis cleanup (remove old dump files)
if systemctl is-active --quiet redis; then
    log "Cleaning old Redis dumps..."
    find /var/lib/redis -name "dump.rdb.*" -type f -mtime +7 -delete 2>/dev/null || true
fi

# Clean old VS Code server instances
log "Cleaning old VS Code server instances..."
if [ -d "/root/.vscode-server" ]; then
    find /root/.vscode-server -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find /root/.vscode-server -name "*.pid" -delete 2>/dev/null || true
fi

# Clean temporary files
log "Cleaning temporary files..."
find /tmp -type f -atime +7 -delete 2>/dev/null || true
find /var/tmp -type f -atime +30 -delete 2>/dev/null || true

# Remove large archive files from server_setup if they exist
log "Cleaning large archive files..."
if [ -f "/root/server_setup/google-cloud-cli-linux-x86_64.tar.gz" ]; then
    if command -v gcloud >/dev/null 2>&1; then
        log "Google Cloud CLI already installed, removing archive..."
        rm -f "/root/server_setup/google-cloud-cli-linux-x86_64.tar.gz" 2>/dev/null || true
    fi
fi

# Clean snap cache
log "Cleaning snap cache..."
if command -v snap >/dev/null 2>&1; then
    snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
        snap remove "$snapname" --revision="$revision" 2>/dev/null || true
    done
fi

# Clean development packages if not needed (commented out for safety)
# log "Removing unused development packages..."
# apt autoremove --purge $(dpkg-query -Wf '${Package}\n' | grep -E "(dev|debug|doc)$") -y 2>/dev/null || true

# Show space freed
FINAL_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
FINAL_USED_KB=$(df / | awk 'NR==2 {print $3}')
FINAL_USED_GB=$(echo "scale=1; $FINAL_USED_KB / 1024 / 1024" | bc)
SPACE_FREED_KB=$((INITIAL_USED_KB - FINAL_USED_KB))
SPACE_FREED_MB=$((SPACE_FREED_KB / 1024))
SPACE_FREED_PERCENT=$((INITIAL_USAGE - FINAL_USAGE))

if [ $SPACE_FREED_MB -gt 1024 ]; then
    SPACE_FREED_GB=$((SPACE_FREED_MB / 1024))
    log "Cleanup completed. Disk usage: ${INITIAL_USAGE}% → ${FINAL_USAGE}% (${SPACE_FREED_GB}GB freed)"
elif [ $SPACE_FREED_MB -gt 0 ]; then
    log "Cleanup completed. Disk usage: ${INITIAL_USAGE}% → ${FINAL_USAGE}% (${SPACE_FREED_MB}MB freed)"
else
    log "Cleanup completed. Disk usage: ${INITIAL_USAGE}% → ${FINAL_USAGE}% (minimal space freed)"
fi

if [ "$FINAL_USAGE" -gt 80 ]; then
    log "WARNING: Disk usage still high (${FINAL_USAGE}%). Manual intervention may be needed."
fi

# Show largest remaining space consumers
log "Largest remaining directories:"
du -sh /root/* /var/log/* 2>/dev/null | sort -hr | head -10 | while read size path; do
    log "  $size $path"
done

# Show final disk usage
log "Running: df -h / (after cleanup)"
FINAL_DF_OUTPUT=$(df -h /)
log "$FINAL_DF_OUTPUT"

# Final summary
log "========================================="
log "CLEANUP SUMMARY:"
log ""
log "BEFORE CLEANUP:"
log "$INITIAL_DF_OUTPUT"
log ""
log "AFTER CLEANUP:"
log "$FINAL_DF_OUTPUT"
log ""
if [ $SPACE_FREED_MB -gt 1024 ]; then
    SPACE_FREED_GB=$((SPACE_FREED_MB / 1024))
    log "✓ Total space cleaned: ${SPACE_FREED_GB}GB (${SPACE_FREED_MB}MB)"
elif [ $SPACE_FREED_MB -gt 0 ]; then
    log "✓ Total space cleaned: ${SPACE_FREED_MB}MB"
else
    log "✓ Minimal space cleaned (less than 1MB)"
fi
log "✓ Disk usage: ${INITIAL_USAGE}% → ${FINAL_USAGE}%"
log "========================================="
log "System cleanup finished."
