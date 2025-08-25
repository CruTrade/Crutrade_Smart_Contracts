#!/bin/bash

# Custom UUPS Upgrade Runner
# This script runs the safe upgrade using manual UUPS pattern

set -e

echo "🚀 Starting Custom UUPS Upgrade..."
echo "=================================="

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create .env file with PRIVATE_KEY and FUJI_RPC variables"
    exit 1
fi

# Load environment variables
echo "📋 Loading environment variables..."
source .env

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY not set in .env file"
    exit 1
fi

if [ -z "$FUJI_RPC" ]; then
    echo "❌ Error: FUJI_RPC not set in .env file"
    exit 1
fi

echo "✅ Environment variables loaded"

# Clean and build contracts
echo "🔨 Building contracts..."
forge clean
forge build --skip test

# Run the custom upgrade script
echo "🚀 Running custom upgrade script..."
echo "🔍 Using Snowtrace for verification..."
forge script script/safe-upgrade-v1.5.0-custom.s.sol:SafeUpgradeV1_5_0Custom \
    --rpc-url $FUJI_RPC \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify

echo ""
echo "✅ Custom UUPS Upgrade Completed!"
echo "=================================="
echo ""
echo "📋 Next Steps:"
echo "1. Verify the upgrade was successful"
echo "2. Test tokenURI() for all tokens (1-28)"
echo "3. Verify setBaseURI function works"
echo "4. Check metadata resolves correctly"
echo "5. Run verification script: bun run script/verify-v1.5.0-upgrade.ts"
echo ""
echo "🔍 To verify the upgrade:"
echo "   bun run script/verify-v1.5.0-upgrade.ts"
echo ""
echo "📚 For more information, see:"
echo "   - SAFE_UPGRADE_V1.5.0_GUIDE.md"