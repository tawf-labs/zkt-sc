#!/bin/bash

# Script to get campaign total raised
# Usage: ./get_campaign_total.sh [campaign_name]

# Load environment variables
source .env

# Get campaign name from argument or use default
CAMPAIGN_NAME=${1:-"RAMADAN-2025-TEST"}

# Calculate campaign ID
CAMPAIGN_ID=$(cast keccak "$CAMPAIGN_NAME")

echo "=========================================="
echo "Campaign: $CAMPAIGN_NAME"
echo "Campaign ID: $CAMPAIGN_ID"
echo "=========================================="

# Query campaign data
echo "Querying campaign data..."
RESULT=$(cast call $POOL_ADDRESS "campaigns(bytes32)" $CAMPAIGN_ID --rpc-url $RPC_URL)

echo "Raw result: $RESULT"
echo ""

# Remove 0x prefix
RESULT_NO_PREFIX="${RESULT:2}"

# Parse the result (7 values, each 64 hex chars = 32 bytes)
# Position 0-63:   exists (bool)
# Position 64-127: allocationLocked (bool)
# Position 128-191: disbursed (bool)
# Position 192-255: closed (bool)
# Position 256-319: totalRaised (uint256) <-- THIS IS WHAT WE WANT
# Position 320-383: startTime (uint256)
# Position 384-447: endTime (uint256)

EXISTS="0x${RESULT_NO_PREFIX:0:64}"
ALLOCATION_LOCKED="0x${RESULT_NO_PREFIX:64:64}"
DISBURSED="0x${RESULT_NO_PREFIX:128:64}"
CLOSED="0x${RESULT_NO_PREFIX:192:64}"
TOTAL_RAISED_HEX="0x${RESULT_NO_PREFIX:256:64}"
START_TIME_HEX="0x${RESULT_NO_PREFIX:320:64}"
END_TIME_HEX="0x${RESULT_NO_PREFIX:384:64}"

# Check if campaign exists
if [ "$EXISTS" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "⚠️  Campaign does not exist!"
    exit 1
fi

# Convert to decimal
TOTAL_RAISED_RAW=$(cast --to-dec $TOTAL_RAISED_HEX)
START_TIME=$(cast --to-dec $START_TIME_HEX)
END_TIME=$(cast --to-dec $END_TIME_HEX)

# Convert from USDC decimals (6) to human readable
TOTAL_RAISED=$(echo "scale=6; $TOTAL_RAISED_RAW / 1000000" | bc)

echo "💰 Total Raised: $TOTAL_RAISED USDC"
echo "   (Raw: $TOTAL_RAISED_RAW)"
echo ""

# Format timestamps
START_DATE=$(date -d @$START_TIME 2>/dev/null || date -r $START_TIME 2>/dev/null || echo "N/A")
END_DATE=$(date -d @$END_TIME 2>/dev/null || date -r $END_TIME 2>/dev/null || echo "N/A")

echo "📅 Campaign Period:"
echo "   Start: $START_DATE"
echo "   End:   $END_DATE"
echo ""

echo "📊 Campaign Status:"
echo "----------------"
[ "$ALLOCATION_LOCKED" != "0x0000000000000000000000000000000000000000000000000000000000000000" ] && echo "✅ Allocation Locked" || echo "❌ Allocation Not Locked"
[ "$DISBURSED" != "0x0000000000000000000000000000000000000000000000000000000000000000" ] && echo "✅ Disbursed" || echo "❌ Not Disbursed"
[ "$CLOSED" != "0x0000000000000000000000000000000000000000000000000000000000000000" ] && echo "✅ Closed" || echo "❌ Open"

echo "=========================================="