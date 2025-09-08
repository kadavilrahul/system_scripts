#!/bin/bash

# Website Backup Unzip Script
# Unzips backup files with interactive options

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

get_folder_path() {
    echo ""
    echo "Select backup folder path:"
    echo -n "Enter folder path [default: /website_backups]: "
    read -r folder_path
    if [ -z "$folder_path" ]; then
        folder_path="/website_backups"
    fi
    echo "$folder_path"
}

show_menu() {
    echo ""
    echo "=== Website Backup Unzip Tool ==="
    echo "1) Unzip individual file"
    echo "2) Unzip all files"
    echo "3) Delete unzipped folders"
    echo "4) Exit"
    echo -n "Select option [1-4]: "
}

delete_unzipped_folders() {
    local backup_dir="$1"
    echo ""
    echo "Looking for unzipped folders in: $backup_dir"
    
    local folders_found=0
    for item in "$backup_dir"/*; do
        if [ -d "$item" ] && [ "$(basename "$item")" != "$(basename "$backup_dir")" ]; then
            folders_found=1
            break
        fi
    done
    
    if [ $folders_found -eq 0 ]; then
        echo "No unzipped folders found."
        return 0
    fi
    
    echo "Found unzipped folders:"
    for item in "$backup_dir"/*; do
        if [ -d "$item" ] && [ "$(basename "$item")" != "$(basename "$backup_dir")" ]; then
            echo "  - $(basename "$item")"
        fi
    done
    
    if confirm_action "Do you want to delete all unzipped folders?"; then
        local deleted_count=0
        for item in "$backup_dir"/*; do
            if [ -d "$item" ] && [ "$(basename "$item")" != "$(basename "$backup_dir")" ]; then
                if rm -rf "$item"; then
                    echo "  ✓ Deleted: $(basename "$item")"
                    log "Deleted folder: $item"
                    ((deleted_count++))
                else
                    echo "  ✗ Failed to delete: $(basename "$item")"
                    log "ERROR: Failed to delete folder: $item"
                fi
            fi
        done
        echo "Deleted $deleted_count folder(s)."
    else
        echo "Deletion cancelled."
    fi
}

BACKUP_DIR=$(get_folder_path)
log "Starting website backup unzip process in: $BACKUP_DIR"

extract_file() {
    local file="$1"
    local backup_dir="$2"
    local basename_file=$(basename "$file")
    local filename="${basename_file%.*}"
    
    if [[ "$basename_file" == *.tar.gz ]]; then
        filename="${filename%.*}"
    elif [[ "$basename_file" == *.tar.bz2 ]]; then
        filename="${filename%.*}"
    fi
    
    local extract_dir="$backup_dir/$filename"
    
    if [ -d "$extract_dir" ]; then
        if ! confirm_action "Folder '$filename' already exists. Overwrite?"; then
            echo "Skipping $basename_file"
            return 1
        fi
        rm -rf "$extract_dir"
    fi
    
    mkdir -p "$extract_dir"
    
    log "Processing: $file -> $extract_dir"
    echo "Extracting: $basename_file -> $filename/"
    
    case "$file" in
        *.tar.gz)
            if tar -xzf "$file" -C "$extract_dir" 2>> "$LOG_FILE"; then
                log "SUCCESS: Extracted $file to $extract_dir"
                echo "  ✓ Successfully extracted to: $extract_dir"
                return 0
            else
                log "ERROR: Failed to extract $file"
                echo "  ✗ Failed to extract $file"
                rm -rf "$extract_dir"
                return 1
            fi
            ;;
        *.tar.bz2)
            if tar -xjf "$file" -C "$extract_dir" 2>> "$LOG_FILE"; then
                log "SUCCESS: Extracted $file to $extract_dir"
                echo "  ✓ Successfully extracted to: $extract_dir"
                return 0
            else
                log "ERROR: Failed to extract $file"
                echo "  ✗ Failed to extract $file"
                rm -rf "$extract_dir"
                return 1
            fi
            ;;
        *.tar)
            if tar -xf "$file" -C "$extract_dir" 2>> "$LOG_FILE"; then
                log "SUCCESS: Extracted $file to $extract_dir"
                echo "  ✓ Successfully extracted to: $extract_dir"
                return 0
            else
                log "ERROR: Failed to extract $file"
                echo "  ✗ Failed to extract $file"
                rm -rf "$extract_dir"
                return 1
            fi
            ;;
        *.zip)
            if unzip -q "$file" -d "$extract_dir" 2>> "$LOG_FILE"; then
                log "SUCCESS: Extracted $file to $extract_dir"
                echo "  ✓ Successfully extracted to: $extract_dir"
                return 0
            else
                log "ERROR: Failed to extract $file"
                echo "  ✗ Failed to extract $file"
                rm -rf "$extract_dir"
                return 1
            fi
            ;;
        *)
            echo "  ✗ Unsupported file format: $basename_file"
            return 1
            ;;
    esac
}

unzip_individual() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir" ]; then
        echo "ERROR: Backup directory $backup_dir does not exist!"
        return 1
    fi
    
    cd "$backup_dir" || return 1
    
    local backup_files=($(find . -maxdepth 1 -name "*.tar.gz" -o -name "*.zip" -o -name "*.tar" -o -name "*.tar.bz2"))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        echo "No backup files found in $backup_dir"
        return 0
    fi
    
    echo ""
    echo "Available backup files:"
    for i in "${!backup_files[@]}"; do
        echo "$((i+1))) $(basename "${backup_files[i]}")"
    done
    
    echo -n "Select file number [1-${#backup_files[@]}]: "
    read -r selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#backup_files[@]} ]; then
        echo "Invalid selection."
        return 1
    fi
    
    local selected_file="${backup_files[$((selection-1))]}"
    extract_file "$selected_file" "$backup_dir"
}

unzip_all() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir" ]; then
        echo "ERROR: Backup directory $backup_dir does not exist!"
        return 1
    fi
    
    cd "$backup_dir" || return 1
    
    local backup_files=($(find . -maxdepth 1 -name "*.tar.gz" -o -name "*.zip" -o -name "*.tar" -o -name "*.tar.bz2"))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        echo "No backup files found in $backup_dir"
        return 0
    fi
    
    echo "Found ${#backup_files[@]} backup file(s) to extract:"
    for file in "${backup_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    
    if ! confirm_action "Do you want to proceed with extracting all backup files?"; then
        log "Operation cancelled by user"
        echo "Operation cancelled."
        return 0
    fi
    
    local success_count=0
    local error_count=0
    
    for file in "${backup_files[@]}"; do
        if extract_file "$file" "$backup_dir"; then
            ((success_count++))
        else
            ((error_count++))
        fi
    done
    
    echo ""
    echo "Extraction completed:"
    echo "  - Successfully extracted: $success_count files"
    echo "  - Failed to extract: $error_count files"
    
    log "Batch unzip process completed. Success: $success_count, Errors: $error_count"
}

while true; do
    show_menu
    read -r choice
    
    case $choice in
        1)
            unzip_individual "$BACKUP_DIR"
            ;;
        2)
            unzip_all "$BACKUP_DIR"
            ;;
        3)
            delete_unzipped_folders "$BACKUP_DIR"
            ;;
        4)
            echo "Goodbye!"
            log "Script terminated by user"
            exit 0
            ;;
        *)
            echo "Invalid option. Please select 1-4."
            ;;
    esac
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
done