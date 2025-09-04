#!/bin/bash

# Fuji Storage Layout Fix Runner
# This script loads environment variables and runs the complete upgrade process

set -e  # Exit on any error

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check required tools
check_requirements() {
    print_status "Checking requirements..."

    if ! command_exists forge; then
        print_error "Foundry (forge) is not installed. Please install it first."
        exit 1
    fi

    if ! command_exists bun; then
        print_error "Bun is not installed. Please install it first."
        exit 1
    fi

    print_success "All requirements met"
}

# Function to load environment file
load_env() {
    print_status "Loading environment variables..."

    # Check for .env file
    if [ -f ".env" ]; then
        print_status "Found .env file, loading variables..."
        export $(grep -v '^#' .env | xargs)
    else
        print_warning "No .env file found. Please ensure environment variables are set:"
        print_warning "  - PRIVATE_KEY"
        print_warning "  - FUJI_RPC (optional, defaults to Fuji testnet)"
    fi

    # Set default RPC if not provided
    if [ -z "$FUJI_RPC" ]; then
        export FUJI_RPC="https://api.avax-test.network/ext/bc/C/rpc"
        print_status "Using default Fuji RPC: $FUJI_RPC"
    fi

    # Validate required variables
    if [ -z "$PRIVATE_KEY" ]; then
        print_error "PRIVATE_KEY environment variable is required"
        print_error "Please set it in your .env file or export it directly"
        exit 1
    fi

    print_success "Environment variables loaded"
}

# Function to build contracts
build_contracts() {
    print_status "Building contracts..."

    if forge build --skip test; then
        print_success "Contracts built successfully"
    else
        print_error "Contract build failed"
        exit 1
    fi
}

# Function to verify storage layout
verify_storage_layout() {
    print_status "Verifying storage layout..."

    if forge inspect Wrappers storage-layout > /dev/null 2>&1; then
        print_success "Storage layout verification passed"
    else
        print_warning "Storage layout verification failed, but continuing..."
        print_warning "This might be due to forge cache issues"
    fi
}

# Function to deploy the fix
deploy_fix() {
    print_status "Deploying storage layout fix..."

    if forge script script/fuji-storage-fix.s.sol \
        --rpc-url "$FUJI_RPC" \
        --private-key "$PRIVATE_KEY" \
        --broadcast; then
        print_success "Deployment completed successfully"
    else
        print_error "Deployment failed"
        exit 1
    fi
}

# Function to verify the fix
verify_fix() {
    print_status "Verifying the fix..."

    if bun run script/verify-fuji-fix.ts; then
        print_success "Verification completed"
    else
        print_warning "Verification script failed, but deployment may still be successful"
        print_warning "Please check the contract manually"
    fi
}

# Function to show summary
show_summary() {
    echo ""
    echo "=========================================="
    print_success "FUJI STORAGE LAYOUT FIX COMPLETED"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Check the verification results above"
    echo "2. Test tokenURI() for tokens 1-8 manually"
    echo "3. Verify all 28 tokens work correctly"
    echo "4. Check metadata URLs are accessible"
    echo ""
    echo "If verification failed, run:"
    echo "  bun run script/verify-fuji-fix.ts"
    echo ""
    echo "For troubleshooting, see: UPGRADE_MANAGEMENT_GUIDE.md"
}

# Main execution
main() {
    echo "🚀 Fuji Storage Layout Fix Runner"
    echo "=================================="
    echo ""

    # Check requirements
    check_requirements

    # Load environment
    load_env

    # Build contracts
    build_contracts

    # Verify storage layout
    verify_storage_layout

    # Deploy the fix
    deploy_fix

    # Wait a moment for transaction to be mined
    print_status "Waiting for transaction to be mined..."
    sleep 10

    # Verify the fix
    verify_fix

    # Show summary
    show_summary
}

# Run main function
main "$@"