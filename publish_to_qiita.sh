#!/bin/bash

# Qiita Publish Script for AXI Pipeline Design Guide
# This script publishes part01*.md and rule*.md files from QiitaDocs/public to Qiita

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the absolute path to QiitaDocs directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QIITA_DOCS_DIR="$SCRIPT_DIR/QiitaDocs"

# Check if QiitaDocs directory exists
if [ ! -d "$QIITA_DOCS_DIR" ]; then
    print_error "QiitaDocs directory not found: $QIITA_DOCS_DIR"
    exit 1
fi

# Check if QiitaDocs/public directory exists
if [ ! -d "$QIITA_DOCS_DIR/public" ]; then
    print_error "QiitaDocs/public directory not found: $QIITA_DOCS_DIR/public"
    exit 1
fi

# Check if npx is available
if ! command -v npx &> /dev/null; then
    print_error "npx is not installed. Please install Node.js and npm first."
    exit 1
fi

# Check if qiita-cli is available (skip version check as it may fail in script context)
print_status "qiita-cli availability check skipped - will attempt to use during publish"

# Function to publish a single file
publish_file() {
    local file="$1"
    local filename=$(basename "$file")
    local filename_without_ext="${filename%.md}"
    
    print_status "Publishing $filename to Qiita as '$filename_without_ext'..."
    
    # Get the absolute path to QiitaDocs directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local qiita_docs_dir="$script_dir/QiitaDocs"
    
    # Check if file exists in public directory
    if [ ! -f "$qiita_docs_dir/public/$filename" ]; then
        print_error "File not found: $qiita_docs_dir/public/$filename"
        return 1
    fi
    
    print_status "File exists: $qiita_docs_dir/public/$filename"
    
    # Change to QiitaDocs directory and execute publish
    if (cd "$qiita_docs_dir" && npx qiita publish "$filename_without_ext"); then
        print_success "Successfully published $filename as '$filename_without_ext'"
    else
        print_error "Failed to publish $filename"
        return 1
    fi
}

# Main execution
main() {
    print_status "Starting Qiita publish process from QiitaDocs/public..."
    
    # Get the absolute path to QiitaDocs directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local qiita_docs_dir="$script_dir/QiitaDocs"
    
    # Find all part*.md files in QiitaDocs/public
    part_files=$(find "$qiita_docs_dir/public" -name "part*.md" -type f)
    
    # Find all rule*.md files in QiitaDocs/public
    rule_files=$(find "$qiita_docs_dir/public" -name "rule*.md" -type f)
    
    # Combine all files to publish
    all_files="$part_files $rule_files"
    
    if [ -z "$all_files" ]; then
        print_error "No part*.md or rule*.md files found in $qiita_docs_dir/public"
        exit 1
    fi
    
    print_status "Found files to publish:"
    for file in $all_files; do
        filename=$(basename "$file")
        filename_without_ext="${filename%.md}"
        echo "  - $filename -> '$filename_without_ext'"
    done
    
    # Publish each file
    failed_files=()
    for file in $all_files; do
        if ! publish_file "$file"; then
            failed_files+=("$file")
        fi
    done
    
    # Summary
    echo ""
    print_status "Publish process completed!"
    
    if [ ${#failed_files[@]} -eq 0 ]; then
        print_success "All files published successfully!"
    else
        print_error "Some files failed to publish:"
        for file in "${failed_files[@]}"; do
            echo "  - $(basename "$file")"
        done
        exit 1
    fi
}

# Run main function
main "$@" 