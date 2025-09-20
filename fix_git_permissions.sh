#!/bin/bash

# Git Repository Permission Fixer
# Fixes permissions for all Git repositories in current directory and subdirectories
# Designed for root-based code execution (not web serving)

# Don't exit on errors - we want to process all repos
# set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory to process (default to current directory)
TARGET_DIR="${1:-.}"
TARGET_DIR=$(realpath "$TARGET_DIR")

echo -e "${GREEN}Git Repository Permission Fixer${NC}"
echo -e "${GREEN}================================${NC}"
echo "Target directory: $TARGET_DIR"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Counter for processed repositories
PROCESSED=0
FAILED=0

# Function to fix a single git repository
fix_git_repo() {
    local repo_dir="$1"
    local git_dir="$repo_dir/.git"
    
    echo -e "${YELLOW}Processing:${NC} $repo_dir"
    
    # Set root ownership for entire repository
    chown -R root:root "$repo_dir" 2>/dev/null || {
        echo -e "  ${RED}✗ Failed to change ownership${NC}"
        ((FAILED++))
        return 1
    }
    
    # Fix .git directory structure
    if [ -d "$git_dir" ]; then
        # Base .git directory
        chmod 755 "$git_dir"
        
        # Fix object database (critical for Git operations)
        if [ -d "$git_dir/objects" ]; then
            find "$git_dir/objects" -type d -exec chmod 755 {} \; 2>/dev/null
            find "$git_dir/objects" -type f -exec chmod 444 {} \; 2>/dev/null
        fi
        
        # Fix references (branches, tags)
        if [ -d "$git_dir/refs" ]; then
            find "$git_dir/refs" -type d -exec chmod 755 {} \; 2>/dev/null
            find "$git_dir/refs" -type f -exec chmod 644 {} \; 2>/dev/null
        fi
        
        # Fix Git metadata files
        [ -f "$git_dir/HEAD" ] && chmod 644 "$git_dir/HEAD"
        [ -f "$git_dir/config" ] && chmod 644 "$git_dir/config"
        [ -f "$git_dir/index" ] && chmod 644 "$git_dir/index"
        [ -f "$git_dir/packed-refs" ] && chmod 644 "$git_dir/packed-refs"
        [ -f "$git_dir/description" ] && chmod 644 "$git_dir/description"
        
        # Fix hooks directory
        if [ -d "$git_dir/hooks" ]; then
            chmod 755 "$git_dir/hooks"
            find "$git_dir/hooks" -type f -exec chmod 755 {} \; 2>/dev/null
        fi
        
        # Fix logs directory
        if [ -d "$git_dir/logs" ]; then
            find "$git_dir/logs" -type d -exec chmod 755 {} \; 2>/dev/null
            find "$git_dir/logs" -type f -exec chmod 644 {} \; 2>/dev/null
        fi
        
        # Fix info directory
        if [ -d "$git_dir/info" ]; then
            chmod 755 "$git_dir/info"
            find "$git_dir/info" -type f -exec chmod 644 {} \; 2>/dev/null
        fi
    fi
    
    # Fix working directory permissions
    # Directories need execute permission
    find "$repo_dir" -type d ! -path "*/.git/*" -exec chmod 755 {} \; 2>/dev/null
    
    # Make scripts executable
    find "$repo_dir" ! -path "*/.git/*" -name "*.sh" -exec chmod 755 {} \; 2>/dev/null
    find "$repo_dir" ! -path "*/.git/*" -name "*.py" -type f -exec chmod 755 {} \; 2>/dev/null
    find "$repo_dir" ! -path "*/.git/*" -name "*.pl" -exec chmod 755 {} \; 2>/dev/null
    find "$repo_dir" ! -path "*/.git/*" -name "*.rb" -exec chmod 755 {} \; 2>/dev/null
    
    # Fix regular files (make them readable)
    find "$repo_dir" ! -path "*/.git/*" -type f ! -name "*.sh" ! -name "*.py" ! -name "*.pl" ! -name "*.rb" -exec chmod 644 {} \; 2>/dev/null
    
    # Special handling for binaries (if they exist)
    find "$repo_dir" ! -path "*/.git/*" -type f -executable -exec chmod 755 {} \; 2>/dev/null
    
    # Test if git operations work (but don't fail if git has ownership issues)
    cd "$repo_dir" 2>/dev/null
    if git status &>/dev/null; then
        echo -e "  ${GREEN}✓ Git operations working${NC}"
    else
        # Try to add safe.directory if there's an ownership issue
        git config --global --add safe.directory "$repo_dir" 2>/dev/null
        if git status &>/dev/null; then
            echo -e "  ${GREEN}✓ Git operations working (added safe.directory)${NC}"
        else
            echo -e "  ${YELLOW}⚠ Git status check failed (repo might be bare or have issues)${NC}"
        fi
    fi
    ((PROCESSED++))
    cd - > /dev/null 2>&1
    return 0
}

# Find all git repositories
echo "Searching for Git repositories..."
echo ""

# Find all .git directories, but exclude .git subdirectories
while IFS= read -r -d '' git_dir; do
    # Get the parent directory (the actual repository)
    repo_dir=$(dirname "$git_dir")
    fix_git_repo "$repo_dir"
done < <(find "$TARGET_DIR" -type d -name ".git" -print0 2>/dev/null)

# Summary
echo ""
echo -e "${GREEN}Summary:${NC}"
echo "------------------------"
echo -e "Processed: ${GREEN}$PROCESSED${NC} repositories"
if [ $FAILED -gt 0 ]; then
    echo -e "Failed: ${RED}$FAILED${NC} repositories"
fi

# Final verification
echo ""
echo -e "${GREEN}Quick Verification:${NC}"
echo "------------------------"

# Show a few sample repos with their status
COUNT=0
while IFS= read -r -d '' git_dir; do
    repo_dir=$(dirname "$git_dir")
    repo_name=$(basename "$repo_dir")
    
    if [ $COUNT -lt 5 ]; then
        echo -n "$repo_name: "
        if cd "$repo_dir" 2>/dev/null && git status &>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
        ((COUNT++))
    else
        remaining=$((PROCESSED - COUNT))
        [ $remaining -gt 0 ] && echo "... and $remaining more repositories"
        break
    fi
done < <(find "$TARGET_DIR" -type d -name ".git" -print0 2>/dev/null)

echo ""
echo -e "${GREEN}✅ Permission fix complete!${NC}"
echo ""
echo "Usage tips:"
echo "  - Run this script in any directory to fix all Git repos within it"
echo "  - Pass a directory path as argument: $0 /path/to/directory"
echo "  - Script must be run as root"
echo "  - Safe to run multiple times"