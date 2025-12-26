#!/bin/bash

# Load environment variables
source .env

# Deploy to Base Sepolia
forge script script/deployzkt.s.sol:Deploy \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY \
  -vvvv

echo ""
echo "Deployment complete!"
echo "Check the broadcast folder for deployment details"
