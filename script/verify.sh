#!/bin/bash

# Crutrade Deployment Verification Script
# This script helps verify that your contracts are properly deployed and configured

set -e

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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        print_success "File exists: $1"
    else
        print_error "File not found: $1"
        return 1
    fi
}

# Function to run verification
run_verification() {
    local network=$1
    local network_id=$2

    print_status "Starting verification for network: $network"
    print_status "Network ID: $network_id"

    # Check if we have the required tools
    if ! command_exists forge; then
        print_error "Foundry (forge) is not installed or not in PATH"
        exit 1
    fi

    if ! command_exists bun; then
        print_error "Bun is not installed or not in PATH"
        exit 1
    fi

    # Check if we have the required files
    check_file "script/verify-deployment.ts"
    check_file "script/verify-deployment.s.sol"
    check_file "script/test-verification.s.sol"
    check_file "script/roles-config.ts"
    check_file "script/payments-config.ts"

    # Check if we have broadcast files
    local broadcast_dir="broadcast/deploy.s.sol/$network_id"
    if [ -d "$broadcast_dir" ]; then
        print_success "Found broadcast directory: $broadcast_dir"
    else
        print_warning "Broadcast directory not found: $broadcast_dir"
        print_warning "Make sure you have deployed contracts first"
    fi

    # Run the TypeScript verification script
    print_status "Running TypeScript verification script..."
    print_status "Environment variables will be loaded automatically from configuration files"

    if bun script/verify-deployment.ts "$network" "$network_id"; then
        print_success "TypeScript verification completed"
    else
        print_error "TypeScript verification failed"
        exit 1
    fi

    # Source environment variables for subsequent commands
    if [ -f ".env.verification" ]; then
        print_status "Loading environment variables from .env.verification"
        export $(cat .env.verification | xargs)
    else
        print_warning "Environment file .env.verification not found"
    fi

    # Run the basic test script
    print_status "Running basic functionality tests..."
    if forge script script/test-verification.s.sol:TestVerification --rpc-url "$(get_rpc_url $network)" --broadcast; then
        print_success "Basic functionality tests completed"
    else
        print_error "Basic functionality tests failed"
        exit 1
    fi
}

# Function to get RPC URL for network
get_rpc_url() {
    local network=$1
    case $network in
        "mainnet")
            echo "${AVALANCHE_RPC_URL:-https://api.avax.network/ext/bc/C/rpc}"
            ;;
        "fuji")
            echo "${FUJI_RPC_URL:-https://api.avax-test.network/ext/bc/C/rpc}"
            ;;
        "local")
            echo "${ANVIL_RPC_URL:-http://localhost:8545}"
            ;;
        *)
            echo "${ANVIL_RPC_URL:-http://localhost:8545}"
            ;;
    esac
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --network NETWORK    Network to verify (local, fuji, mainnet) [default: local]"
    echo "  -i, --network-id ID      Network ID [default: 31337 for local, 43113 for fuji, 43114 for mainnet]"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Verify local deployment"
    echo "  $0 -n fuji                           # Verify Fuji testnet deployment"
    echo "  $0 -n mainnet                        # Verify mainnet deployment"
    echo "  $0 -n local -i 31337                # Verify local deployment with specific network ID"
    echo ""
    echo "Environment Variables (Optional - will be loaded from config files):"
    echo "  AVALANCHE_RPC_URL      RPC URL for Avalanche mainnet"
    echo "  FUJI_RPC_URL           RPC URL for Fuji testnet"
    echo "  ANVIL_RPC_URL          RPC URL for local Anvil instance"
    echo ""
    echo "Note: All role and payment configuration will be loaded automatically"
    echo "from script/roles-config.ts and script/payments-config.ts"
}

# Parse command line arguments
NETWORK="local"
NETWORK_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--network)
            NETWORK="$2"
            shift 2
            ;;
        -i|--network-id)
            NETWORK_ID="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set default network ID if not provided
if [ -z "$NETWORK_ID" ]; then
    case $NETWORK in
        "mainnet")
            NETWORK_ID="43114"
            ;;
        "fuji")
            NETWORK_ID="43113"
            ;;
        "local")
            NETWORK_ID="31337"
            ;;
        *)
            NETWORK_ID="31337"
            ;;
    esac
fi

# Validate network
case $NETWORK in
    "local"|"fuji"|"mainnet")
        ;;
    *)
        print_error "Invalid network: $NETWORK"
        print_error "Valid networks: local, fuji, mainnet"
        exit 1
        ;;
esac

# Show configuration info
print_status "Configuration will be loaded from:"
print_status "  - Roles: script/roles-config.ts"
print_status "  - Payments: script/payments-config.ts"
print_status "  - Network: $NETWORK"

# Run verification
run_verification "$NETWORK" "$NETWORK_ID"

print_success "Verification completed successfully!"