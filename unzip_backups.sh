#!/bin/bash

# Website Backup Unzip Script
# Unzips all backup files from /website_backups directory

BACKUP_DIR="/website_backups"
EXTRACT_DIR="/website_backups"
LOG_FILE="/var/log/backup-unzip.log"
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

log "Starting website backup unzip process..."

if [ ! -d "$BACKUP_DIR" ]; then
    log "ERROR: Backup directory $BACKUP_DIR does not exist!"
    exit 1
fi

cd "$BACKUP_DIR" || exit 1

BACKUP_FILES=$(find . -maxdepth 1 -name "*.tar.gz" -o -name "*.zip" -o -name "*.tar" -o -name "*.tar.bz2" | wc -l)

if [ "$BACKUP_FILES" -eq 0 ]; then
    log "No backup files found in $BACKUP_DIR"
    echo "No backup files found in $BACKUP_DIR"
    exit 0
fi

echo "Found $BACKUP_FILES backup file(s) to extract:"
find . -maxdepth 1 -name "*.tar.gz" -o -name "*.zip" -o -name "*.tar" -o -name "*.tar.bz2" | while read -r file; do
    echo "  - $file"
done

if ! confirm_action "Do you want to proceed with extracting all backup files?"; then
    log "Operation cancelled by user"
    echo "Operation cancelled."
    exit 0
fi

SUCCESS_COUNT=0
ERROR_COUNT=0

# Use a different approach to avoid subshell variable issues
TEMP_FILE="/tmp/backup_results_$$"
echo "0 0" > "$TEMP_FILE"

find . -maxdepth 1 \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.tar" -o -name "*.tar.bz2" \) | while read -r file; do
    BASENAME=$(basename "$file")
    FILENAME="${BASENAME%.*}"
    if [[ "$BASENAME" == *.tar.gz ]]; then
        FILENAME="${FILENAME%.*}"
    fi
    
    log "Processing: $file"
    echo "Extracting: $BASENAME"
    
    case "$file" in
        *.tar.gz)
            if tar -xzf "$file" -C "$EXTRACT_DIR" 2>> "$LOG_FILE"; then
                log "SUCCESS: Extracted $file to $EXTRACT_DIR"
                echo "  ✓ Successfully extracted to: $EXTRACT_DIR"
                read success error < "$TEMP_FILE"
                echo "$((success + 1)) $error" > "$TEMP_FILE"
            else
                log "ERROR: Failed to extract $file"
                echo "  ✗ Failed to extract $file"
                read success error < "$TEMP_FILE"
                echo "$success $((error + 1))" > "$TEMP_FILE"
            fi
            ;;
        *.tar.bz2)
            if tar -xjf "$file" -C "$EXTRACT_DIR" 2>> "$LOG_FILE"; then
                log "SUCCESS: Extracted $file to $EXTRACT_DIR"
                echo "  ✓ Successfully extracted to: $EXTRACT_DIR"
                read success error < "$TEMP_FILE"
                echo "$((success + 1)) $error" > "$TEMP_FILE"
            else
                log "ERROR: Failed to extract $file"
                echo "  ✗ Failed to extract $file"
                read success error < "$TEMP_FILE"
                echo "$success $((error + 1))" > "$TEMP_FILE"
            fi
            ;;
        *.tar)
            if tar -xf "$file" -C "$EXTRACT_DIR" 2>> "$LOG_FILE"; then
                log "SUCCESS: Extracted $file to $EXTRACT_DIR"
                echo "  ✓ Successfully extracted to: $EXTRACT_DIR"
                read success error < "$TEMP_FILE"
                echo "$((success + 1)) $error" > "$TEMP_FILE"
            else
                log "ERROR: Failed to extract $file"
                echo "  ✗ Failed to extract $file"
                read success error < "$TEMP_FILE"
                echo "$success $((error + 1))" > "$TEMP_FILE"
            fi
            ;;
        *.zip)
            if unzip -q "$file" -d "$EXTRACT_DIR" 2>> "$LOG_FILE"; then
                log "SUCCESS: Extracted $file to $EXTRACT_DIR"
                echo "  ✓ Successfully extracted to: $EXTRACT_DIR"
                read success error < "$TEMP_FILE"
                echo "$((success + 1)) $error" > "$TEMP_FILE"
            else
                log "ERROR: Failed to extract $file"
                echo "  ✗ Failed to extract $file"
                read success error < "$TEMP_FILE"
                echo "$success $((error + 1))" > "$TEMP_FILE"
            fi
            ;;
    esac
done

# Read final counts
read SUCCESS_COUNT ERROR_COUNT < "$TEMP_FILE"
rm -f "$TEMP_FILE"

echo ""
echo "Extraction completed:"
echo "  - Successfully extracted: $SUCCESS_COUNT files"
echo "  - Failed to extract: $ERROR_COUNT files"

if [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo ""
    echo "Extracted files are located in: $EXTRACT_DIR"
    echo "Directory structure:"
    find "$EXTRACT_DIR" -maxdepth 1 -not -name "*.tar.gz" -not -name "*.zip" -not -name "*.tar" -not -name "*.tar.bz2" -not -path "$EXTRACT_DIR" | head -10 2>/dev/null || echo "  (No files extracted)"
fi

log "Backup unzip process completed. Success: $SUCCESS_COUNT, Errors: $ERROR_COUNT"