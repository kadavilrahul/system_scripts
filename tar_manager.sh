#!/bin/bash

# TAR Manager Script
# Interactive tool for searching, extracting, and managing tar files

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - TAR_MANAGER: $1" >> /var/log/system-cleanup.log
}

# Function to display colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to confirm actions
confirm_action() {
    echo -n "$1 (y/N): "
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to validate tar file
validate_tar_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        print_color "$RED" "❌ Error: File '$file' does not exist."
        return 1
    fi
    
    # Check if file has .tar extension or is a compressed tar
    if [[ ! "$file" =~ \.(tar|tar\.gz|tgz|tar\.bz2|tbz2|tar\.xz|txz)$ ]]; then
        print_color "$YELLOW" "⚠️  Warning: File doesn't appear to be a tar archive based on extension."
        if ! confirm_action "Continue anyway?"; then
            return 1
        fi
    fi
    
    # Test if tar can read the file
    if ! tar -tf "$file" >/dev/null 2>&1; then
        print_color "$RED" "❌ Error: File '$file' is not a valid tar archive or is corrupted."
        return 1
    fi
    
    return 0
}

# Function to get tar command based on file type
get_tar_command() {
    local file="$1"
    
    if [[ "$file" =~ \.tar\.gz$ ]] || [[ "$file" =~ \.tgz$ ]]; then
        echo "tar -tzf"
    elif [[ "$file" =~ \.tar\.bz2$ ]] || [[ "$file" =~ \.tbz2$ ]]; then
        echo "tar -tjf"
    elif [[ "$file" =~ \.tar\.xz$ ]] || [[ "$file" =~ \.txz$ ]]; then
        echo "tar -tJf"
    else
        echo "tar -tf"
    fi
}

# Function to get extraction command based on file type
get_extract_command() {
    local file="$1"
    
    if [[ "$file" =~ \.tar\.gz$ ]] || [[ "$file" =~ \.tgz$ ]]; then
        echo "tar -xzf"
    elif [[ "$file" =~ \.tar\.bz2$ ]] || [[ "$file" =~ \.tbz2$ ]]; then
        echo "tar -xjf"
    elif [[ "$file" =~ \.tar\.xz$ ]] || [[ "$file" =~ \.txz$ ]]; then
        echo "tar -xJf"
    else
        echo "tar -xf"
    fi
}

# Function to search/list contents of tar file
search_tar_contents() {
    print_color "$CYAN" "🔍 TAR CONTENT SEARCH"
    print_color "$CYAN" "========================================"
    
    # Get tar file path
    if [ -n "$1" ]; then
        TAR_FILE="$1"
    else
        echo -n "Enter path to tar file: "
        read -r TAR_FILE
    fi
    
    # Validate tar file
    if ! validate_tar_file "$TAR_FILE"; then
        return 1
    fi
    
    # Get file info
    local file_size=$(ls -lh "$TAR_FILE" | awk '{print $5}')
    local file_name=$(basename "$TAR_FILE")
    
    print_color "$BLUE" "📁 Archive: $file_name"
    print_color "$BLUE" "📊 Size: $file_size"
    echo ""
    
    # Get tar command
    local tar_cmd=$(get_tar_command "$TAR_FILE")
    
    # Count total files
    local total_files=$($tar_cmd "$TAR_FILE" | wc -l)
    print_color "$GREEN" "📋 Total entries: $total_files"
    echo ""
    
    # Menu for search options
    while true; do
        print_color "$YELLOW" "Search Options:"
        echo "1) List all contents"
        echo "2) Search by filename pattern"
        echo "3) List directories only"
        echo "4) List files only"
        echo "5) Search by file extension"
        echo "6) Show largest files"
        echo "0) Back to main menu"
        echo ""
        echo -n "Choose option (0-6): "
        read -r search_option
        
        case $search_option in
            1)
                print_color "$BLUE" "📄 Complete archive contents:"
                echo "========================================"
                $tar_cmd "$TAR_FILE" | head -50
                if [ $total_files -gt 50 ]; then
                    print_color "$YELLOW" "... showing first 50 of $total_files entries"
                    echo -n "Show all entries? (y/N): "
                    read -r response
                    if [[ "$response" =~ ^[yY] ]]; then
                        $tar_cmd "$TAR_FILE" | less
                    fi
                fi
                ;;
            2)
                echo -n "Enter filename pattern (e.g., *.txt, config*, etc.): "
                read -r pattern
                print_color "$BLUE" "🔍 Files matching '$pattern':"
                echo "========================================"
                $tar_cmd "$TAR_FILE" | grep -i "$pattern" | head -20
                ;;
            3)
                print_color "$BLUE" "📁 Directories in archive:"
                echo "========================================"
                $tar_cmd "$TAR_FILE" | grep '/$' | head -20
                ;;
            4)
                print_color "$BLUE" "📄 Files in archive:"
                echo "========================================"
                $tar_cmd "$TAR_FILE" | grep -v '/$' | head -20
                ;;
            5)
                echo -n "Enter file extension (e.g., .txt, .php, .sql): "
                read -r ext
                print_color "$BLUE" "🔍 Files with extension '$ext':"
                echo "========================================"
                $tar_cmd "$TAR_FILE" | grep -i "\.$ext\$" | head -20
                ;;
            6)
                print_color "$BLUE" "📊 File size analysis:"
                echo "========================================"
                print_color "$YELLOW" "Note: Tar archives don't store individual file sizes in standard format."
                print_color "$YELLOW" "Showing files sorted by name length as approximation:"
                $tar_cmd "$TAR_FILE" | grep -v '/$' | awk '{print length, $0}' | sort -nr | head -10 | cut -d' ' -f2-
                ;;
            0)
                return 0
                ;;
            *)
                print_color "$RED" "Invalid option. Please choose 0-6."
                ;;
        esac
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Function to extract specific files
extract_specific_files() {
    print_color "$CYAN" "📦 EXTRACT SPECIFIC FILES"
    print_color "$CYAN" "========================================"
    
    # Get tar file path
    if [ -n "$1" ]; then
        TAR_FILE="$1"
    else
        echo -n "Enter path to tar file: "
        read -r TAR_FILE
    fi
    
    # Validate tar file
    if ! validate_tar_file "$TAR_FILE"; then
        return 1
    fi
    
    # Get extraction directory
    echo -n "Enter extraction directory (default: current directory): "
    read -r extract_dir
    if [ -z "$extract_dir" ]; then
        extract_dir="."
    fi
    
    # Create extraction directory if it doesn't exist
    if [ ! -d "$extract_dir" ]; then
        if confirm_action "Directory '$extract_dir' doesn't exist. Create it?"; then
            mkdir -p "$extract_dir" || {
                print_color "$RED" "❌ Failed to create directory '$extract_dir'"
                return 1
            }
        else
            return 1
        fi
    fi
    
    print_color "$BLUE" "📁 Available extraction methods:"
    echo "1) Extract specific files by name"
    echo "2) Extract files matching pattern"
    echo "3) Extract files by extension"
    echo "4) Interactive file selection"
    echo "0) Back to main menu"
    echo ""
    echo -n "Choose method (0-4): "
    read -r extract_method
    
    local tar_cmd=$(get_extract_command "$TAR_FILE")
    local files_to_extract=""
    
    case $extract_method in
        1)
            echo "Enter file paths to extract (one per line, empty line to finish):"
            while true; do
                echo -n "> "
                read -r file_path
                if [ -z "$file_path" ]; then
                    break
                fi
                files_to_extract="$files_to_extract $file_path"
            done
            ;;
        2)
            echo -n "Enter pattern (e.g., *.txt, config*, etc.): "
            read -r pattern
            local list_cmd=$(get_tar_command "$TAR_FILE")
            files_to_extract=$($list_cmd "$TAR_FILE" | grep "$pattern" | tr '\n' ' ')
            ;;
        3)
            echo -n "Enter file extension (e.g., .txt, .php): "
            read -r ext
            local list_cmd=$(get_tar_command "$TAR_FILE")
            files_to_extract=$($list_cmd "$TAR_FILE" | grep "\.$ext\$" | tr '\n' ' ')
            ;;
        4)
            print_color "$BLUE" "🔍 Listing archive contents for selection..."
            local list_cmd=$(get_tar_command "$TAR_FILE")
            local temp_file=$(mktemp)
            $list_cmd "$TAR_FILE" > "$temp_file"
            
            echo "Select files to extract (enter line numbers, separated by spaces):"
            cat -n "$temp_file" | head -20
            echo ""
            echo -n "Enter line numbers: "
            read -r line_numbers
            
            for line_num in $line_numbers; do
                local file_path=$(sed -n "${line_num}p" "$temp_file")
                files_to_extract="$files_to_extract $file_path"
            done
            
            rm -f "$temp_file"
            ;;
        0)
            return 0
            ;;
        *)
            print_color "$RED" "Invalid option."
            return 1
            ;;
    esac
    
    if [ -z "$files_to_extract" ]; then
        print_color "$YELLOW" "⚠️  No files specified for extraction."
        return 1
    fi
    
    # Show files to be extracted
    print_color "$BLUE" "📋 Files to extract:"
    for file in $files_to_extract; do
        echo "   $file"
    done
    echo ""
    
    if ! confirm_action "Extract these files to '$extract_dir'?"; then
        echo "Extraction cancelled."
        return 1
    fi
    
    # Perform extraction
    print_color "$GREEN" "🔄 Extracting files..."
    cd "$extract_dir" || {
        print_color "$RED" "❌ Failed to change to directory '$extract_dir'"
        return 1
    }
    
    log "Extracting specific files from $TAR_FILE to $extract_dir"
    
    if eval "$tar_cmd \"$TAR_FILE\" $files_to_extract" 2>/dev/null; then
        print_color "$GREEN" "✅ Extraction completed successfully!"
        
        # Show extracted files
        echo ""
        print_color "$BLUE" "📁 Extracted files:"
        for file in $files_to_extract; do
            if [ -e "$file" ]; then
                local size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}' || echo "unknown")
                echo "   ✓ $file ($size)"
            fi
        done
    else
        print_color "$RED" "❌ Extraction failed. Check file paths and permissions."
        return 1
    fi
}

# Function to extract with folder exclusions
extract_with_exclusions() {
    print_color "$CYAN" "📦 EXTRACT WITH EXCLUSIONS"
    print_color "$CYAN" "========================================"
    
    # Get tar file path
    if [ -n "$1" ]; then
        TAR_FILE="$1"
    else
        echo -n "Enter path to tar file: "
        read -r TAR_FILE
    fi
    
    # Validate tar file
    if ! validate_tar_file "$TAR_FILE"; then
        return 1
    fi
    
    # Get extraction directory
    echo -n "Enter extraction directory (default: current directory): "
    read -r extract_dir
    if [ -z "$extract_dir" ]; then
        extract_dir="."
    fi
    
    # Create extraction directory if it doesn't exist
    if [ ! -d "$extract_dir" ]; then
        if confirm_action "Directory '$extract_dir' doesn't exist. Create it?"; then
            mkdir -p "$extract_dir" || {
                print_color "$RED" "❌ Failed to create directory '$extract_dir'"
                return 1
            }
        else
            return 1
        fi
    fi
    
    # Show directories in archive
    print_color "$BLUE" "📁 Directories in archive:"
    local list_cmd=$(get_tar_command "$TAR_FILE")
    $list_cmd "$TAR_FILE" | grep '/$' | head -20
    echo ""
    
    # Get exclusion patterns
    print_color "$YELLOW" "🚫 Specify folders/patterns to exclude:"
    echo "Examples: temp/, *.log, cache/, node_modules/"
    echo "Enter exclusion patterns (one per line, empty line to finish):"
    
    local exclusions=""
    local exclude_args=""
    
    while true; do
        echo -n "> "
        read -r exclusion
        if [ -z "$exclusion" ]; then
            break
        fi
        exclusions="$exclusions $exclusion"
        exclude_args="$exclude_args --exclude='$exclusion'"
    done
    
    if [ -z "$exclusions" ]; then
        print_color "$YELLOW" "⚠️  No exclusions specified. This will extract all files."
        if ! confirm_action "Continue with full extraction?"; then
            return 1
        fi
    else
        print_color "$BLUE" "🚫 Will exclude:"
        for excl in $exclusions; do
            echo "   $excl"
        done
        echo ""
    fi
    
    if ! confirm_action "Extract archive to '$extract_dir' with specified exclusions?"; then
        echo "Extraction cancelled."
        return 1
    fi
    
    # Perform extraction
    print_color "$GREEN" "🔄 Extracting files with exclusions..."
    cd "$extract_dir" || {
        print_color "$RED" "❌ Failed to change to directory '$extract_dir'"
        return 1
    }
    
    local tar_cmd=$(get_extract_command "$TAR_FILE")
    log "Extracting $TAR_FILE to $extract_dir with exclusions: $exclusions"
    
    # Build and execute the command
    local full_command="$tar_cmd \"$TAR_FILE\" $exclude_args"
    
    if eval "$full_command" 2>/dev/null; then
        print_color "$GREEN" "✅ Extraction completed successfully!"
        
        # Show extraction results
        local extracted_count=$(find . -type f -newer "$TAR_FILE" 2>/dev/null | wc -l)
        local total_size=$(du -sh . 2>/dev/null | cut -f1)
        
        echo ""
        print_color "$BLUE" "📊 Extraction Summary:"
        echo "   Files extracted: $extracted_count"
        echo "   Total size: $total_size"
        echo "   Location: $(pwd)"
    else
        print_color "$RED" "❌ Extraction failed. Check permissions and disk space."
        return 1
    fi
}

# Main menu function
show_main_menu() {
    clear
    print_color "$CYAN" "========================================================================================"
    print_color "$CYAN" "                                    TAR MANAGER"
    print_color "$CYAN" "========================================================================================"
    echo "1) Search/List Tar Contents    - Browse and search files in tar archives"
    echo "2) Extract Specific Files      - Extract selected files from tar archive"  
    echo "3) Extract with Exclusions     - Extract archive excluding specific folders/patterns"
    echo "4) Batch Operations            - Perform operations on multiple tar files"
    echo "0) Back to main system menu"
    print_color "$CYAN" "========================================================================================"
    echo -n "Please select an option (0-4): "
}

# Batch operations function
batch_operations() {
    print_color "$CYAN" "📦 BATCH OPERATIONS"
    print_color "$CYAN" "========================================"
    
    echo -n "Enter directory containing tar files (default: current directory): "
    read -r tar_dir
    if [ -z "$tar_dir" ]; then
        tar_dir="."
    fi
    
    if [ ! -d "$tar_dir" ]; then
        print_color "$RED" "❌ Directory '$tar_dir' does not exist."
        return 1
    fi
    
    # Find tar files
    local tar_files=$(find "$tar_dir" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.bz2" -o -name "*.tbz2" -o -name "*.tar.xz" -o -name "*.txz" \) | sort)
    
    if [ -z "$tar_files" ]; then
        print_color "$YELLOW" "⚠️  No tar files found in '$tar_dir'"
        return 1
    fi
    
    local count=$(echo "$tar_files" | wc -l)
    print_color "$GREEN" "📋 Found $count tar files:"
    echo "$tar_files" | nl
    echo ""
    
    print_color "$YELLOW" "Batch Operations:"
    echo "1) List contents of all tar files"
    echo "2) Extract all tar files (each to its own directory)"
    echo "3) Search pattern across all tar files"
    echo "0) Back to main menu"
    echo ""
    echo -n "Choose operation (0-3): "
    read -r batch_option
    
    case $batch_option in
        1)
            print_color "$BLUE" "📄 Listing contents of all tar files:"
            echo "$tar_files" | while read -r tar_file; do
                echo ""
                print_color "$YELLOW" "=== $(basename "$tar_file") ==="
                local list_cmd=$(get_tar_command "$tar_file")
                $list_cmd "$tar_file" | head -10
                local total=$($list_cmd "$tar_file" | wc -l)
                echo "   ... ($total total entries)"
            done
            ;;
        2)
            if confirm_action "Extract all $count tar files to separate directories?"; then
                echo "$tar_files" | while read -r tar_file; do
                    local basename_file=$(basename "$tar_file")
                    local dir_name="${basename_file%.*}"
                    if [[ "$basename_file" =~ \.tar\.gz$ ]] || [[ "$basename_file" =~ \.tar\.bz2$ ]] || [[ "$basename_file" =~ \.tar\.xz$ ]]; then
                        dir_name="${basename_file%.*.*}"
                    fi
                    
                    mkdir -p "$dir_name"
                    print_color "$GREEN" "🔄 Extracting $basename_file to $dir_name/"
                    
                    local extract_cmd=$(get_extract_command "$tar_file")
                    cd "$dir_name" && eval "$extract_cmd \"$tar_file\"" && cd ..
                done
                print_color "$GREEN" "✅ Batch extraction completed!"
            fi
            ;;
        3)
            echo -n "Enter search pattern: "
            read -r search_pattern
            print_color "$BLUE" "🔍 Searching for '$search_pattern' in all tar files:"
            echo "$tar_files" | while read -r tar_file; do
                local list_cmd=$(get_tar_command "$tar_file")
                local matches=$($list_cmd "$tar_file" | grep -i "$search_pattern")
                if [ -n "$matches" ]; then
                    echo ""
                    print_color "$YELLOW" "=== $(basename "$tar_file") ==="
                    echo "$matches"
                fi
            done
            ;;
        0)
            return 0
            ;;
        *)
            print_color "$RED" "Invalid option."
            ;;
    esac
}

# Main program loop
main() {
    # Check if running with parameters for direct function calls
    case "$1" in
        --search)
            search_tar_contents "$2"
            exit 0
            ;;
        --extract)
            extract_specific_files "$2"
            exit 0
            ;;
        --exclude)
            extract_with_exclusions "$2"
            exit 0
            ;;
        --batch)
            batch_operations
            exit 0
            ;;
        --help)
            print_color "$CYAN" "TAR Manager - Interactive tar file management tool"
            echo ""
            echo "Usage: $0 [OPTION] [TAR_FILE]"
            echo ""
            echo "Options:"
            echo "  --search [TAR_FILE]   Search/list contents of tar file"
            echo "  --extract [TAR_FILE]  Extract specific files from tar"
            echo "  --exclude [TAR_FILE]  Extract with folder exclusions"
            echo "  --batch              Batch operations on multiple files"
            echo "  --help               Show this help message"
            echo ""
            echo "If no option is provided, interactive menu will be shown."
            exit 0
            ;;
    esac
    
    # Check if we're in a non-interactive environment
    if [ ! -t 0 ]; then
        print_color "$YELLOW" "⚠️  Non-interactive environment detected."
        print_color "$BLUE" "Use --help to see available command-line options."
        exit 1
    fi
    
    # Interactive menu
    local max_attempts=50  # Prevent infinite loops
    local attempts=0
    
    while [ $attempts -lt $max_attempts ]; do
        show_main_menu
        
        # Use timeout for read to prevent infinite hanging
        if read -t 30 -r choice; then
            case $choice in
                1)
                    search_tar_contents
                    ;;
                2)
                    extract_specific_files
                    ;;
                3)
                    extract_with_exclusions
                    ;;
                4)
                    batch_operations
                    ;;
                0)
                    print_color "$GREEN" "Returning to main system menu."
                    exit 0
                    ;;
                *)
                    print_color "$RED" "Invalid option. Please select 0-4."
                    ;;
            esac
            echo ""
            read -t 10 -p "Press Enter to continue..."
        else
            print_color "$YELLOW" "⚠️  Input timeout. Exiting."
            exit 1
        fi
        
        attempts=$((attempts + 1))
    done
    
    print_color "$YELLOW" "⚠️  Maximum attempts reached. Exiting."
    exit 1
}

# Make sure script is executable
if [ "$0" = "${BASH_SOURCE[0]}" ]; then
    main "$@"
fi