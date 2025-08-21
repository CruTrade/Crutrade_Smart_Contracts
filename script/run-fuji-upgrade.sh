#!/bin/bash

# Fuji Upgrade Script
# This script upgrades the Wrappers contract on Fuji testnet

set -e

echo "🚀 Starting Fuji Wrappers Upgrade"
echo "=================================="

# Load environment variables from .env if it exists
if [ -f ".env" ]; then
    echo "📄 Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if we're on the upgradeURI branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "❌ Error: You must be on the 'main' branch to run this upgrade"
    echo "Current branch: $CURRENT_BRANCH"
    echo "Please run: git checkout main"
    exit 1
fi

# Check if environment variables are set
if [ -z "$FUJI_RPC_URL" ]; then
    echo "❌ Error: FUJI_RPC_URL environment variable not set"
    echo "Please set it in your .env file or export it:"
    echo "export FUJI_RPC_URL=\"https://api.avax-test.network/ext/bc/C/rpc\""
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY environment variable not set"
    echo "Please set it in your .env file or export it:"
    echo "export PRIVATE_KEY=\"your_private_key_here\""
    exit 1
fi

echo "✅ Environment variables loaded successfully"
echo "RPC URL: $FUJI_RPC_URL"
echo "Private Key: ${PRIVATE_KEY:0:5}..."

# Build contracts
echo "📦 Building contracts..."
forge build --via-ir

# Run the upgrade script
echo "🔄 Executing upgrade..."
forge script script/fuji-upgrade.s.sol \
    --rpc-url "$FUJI_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --via-ir \
    --verify

echo ""
echo "✅ Fuji upgrade completed!"
echo ""
echo "🔍 Next steps:"
echo "1. Check the transaction on Fuji block explorer"
echo "2. Verify the new implementation address"
echo "3. Test tokenURI() on existing NFTs"
echo "4. Verify metadata resolves correctly"