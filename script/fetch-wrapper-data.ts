/// <reference types="bun-types" />

import { $ } from "bun";
import { argv, env } from "process";
import { createPublicClient, http, parseAbi, encodeFunctionData } from "viem";
import { avalanche, avalancheFuji, anvil } from "viem/chains";
import { abi, addresses } from '../config';

// Type definitions
interface WrapperData {
  metaKey: string;
  uri: string;
  amount: bigint;
  tokenId: bigint;
  brandId: bigint;
  collection: string; // Changed from bytes32 to string based on actual data
  active: boolean;
}

interface FetchResult {
  tokenId: number;
  success: boolean;
  data?: WrapperData;
  error?: string;
}

// Network config mapping
const chainConfigs = {
  local: {
    chain: anvil,
    rpc: anvil.rpcUrls.default.http[0],
  },
  testnet: {
    chain: avalancheFuji,
    rpc: avalancheFuji.rpcUrls.default.http[0],
  },
  mainnet: {
    chain: avalanche,
    rpc: avalanche.rpcUrls.default.http[0],
  },
};

const network = (argv[2] || env.NETWORK || "local") as keyof typeof chainConfigs;
const config = chainConfigs[network];

if (!config) {
  console.error(`Unknown network: ${network}`);
  process.exit(1);
}

// Wrappers contract ABI - corrected to match the actual WrapperData struct
const WRAPPERS_ABI = parseAbi([
  "function getWrapperData(uint256 wrapperId) view returns (string uri, string metaKey, uint256 amount, uint256 tokenId, uint256 brandId, bytes32 collection, bool active)"
]);

/**
 * Makes a raw staticcall to get the return data without parsing
 */
async function getRawReturnData(
  tokenId: number,
  contractAddress: `0x${string}`,
  client: ReturnType<typeof createPublicClient>
): Promise<string> {
  const functionData = encodeFunctionData({
    abi: WRAPPERS_ABI,
    functionName: 'getWrapperData',
    args: [BigInt(tokenId)]
  });

  const result = await client.call({
    to: contractAddress,
    data: functionData
  });

  return result.data || '0x';
}

/**
 * Manually decodes the raw return data from getWrapperData
 * This is useful for debugging when ABI parsing fails
 */
function decodeRawWrapperData(rawData: string): WrapperData | null {
  try {
    // Remove 0x prefix
    const data = rawData.startsWith('0x') ? rawData.slice(2) : rawData;
    
    // The first 32 bytes (64 hex chars) is the offset to the struct
    const structOffset = parseInt(data.slice(0, 64), 16);
    
    // Read the struct data starting from the offset
    const structData = data.slice(structOffset * 2);
    
    // Parse each field according to the struct layout
    let offset = 0;
    
    // uri offset (32 bytes)
    const uriOffset = parseInt(structData.slice(offset, offset + 64), 16);
    offset += 64;
    
    // metaKey offset (32 bytes)
    const metaKeyOffset = parseInt(structData.slice(offset, offset + 64), 16);
    offset += 64;
    
    // amount (32 bytes)
    const amount = BigInt('0x' + structData.slice(offset, offset + 64));
    offset += 64;
    
    // tokenId (32 bytes)
    const tokenId = BigInt('0x' + structData.slice(offset, offset + 64));
    offset += 64;
    
    // brandId (32 bytes)
    const brandId = BigInt('0x' + structData.slice(offset, offset + 64));
    offset += 64;
    
    // collection (32 bytes) - this is a bytes32, not a string
    const collectionHex = structData.slice(offset, offset + 64);
    offset += 64;
    
    // active (32 bytes, padded)
    const active = parseInt(structData.slice(offset, offset + 64), 16) === 1;
    
    // Read dynamic strings
    const uriLength = parseInt(data.slice(uriOffset * 2, uriOffset * 2 + 64), 16);
    const uriStart = uriOffset * 2 + 64;
    const uriHex = data.slice(uriStart, uriStart + uriLength * 2);
    const uri = Buffer.from(uriHex, 'hex').toString('utf8');
    
    const metaKeyLength = parseInt(data.slice(metaKeyOffset * 2, metaKeyOffset * 2 + 64), 16);
    const metaKeyStart = metaKeyOffset * 2 + 64;
    const metaKeyHex = data.slice(metaKeyStart, metaKeyStart + metaKeyLength * 2);
    const metaKey = Buffer.from(metaKeyHex, 'hex').toString('utf8');
    
    // Convert collection from hex to string (remove trailing zeros)
    const collectionBytes = Buffer.from(collectionHex, 'hex');
    const collectionString = collectionBytes.toString('utf8').replace(/\0+$/, '');
    
    return {
      uri,
      metaKey,
      amount,
      tokenId,
      brandId,
      collection: collectionString,
      active
    };
  } catch (error) {
    console.log(`Failed to decode raw data: ${error}`);
    return null;
  }
}

/**
 * Fetches WrapperData for an array of tokenIds
 * @param tokenIds - Array of wrapper token IDs to fetch
 * @param contractAddress - Address of the Wrappers contract
 * @param client - Viem public client
 * @returns Array of wrapper data objects
 */
async function fetchWrapperData(
  tokenIds: number[],
  contractAddress: `0x${string}`,
  client: ReturnType<typeof createPublicClient>
): Promise<FetchResult[]> {
  if (!tokenIds || tokenIds.length === 0) {
    throw new Error("TokenIds array cannot be empty");
  }

  console.log(`Fetching wrapper data for ${tokenIds.length} token(s) on ${network}...`);
  console.log(`Contract Address: ${contractAddress}`);
  console.log(`RPC URL: ${config.rpc}`);
  console.log(`Chain ID: ${config.chain.id}`);
  console.log("");

  // Fetch data for all tokenIds in parallel
  const results = await Promise.allSettled(
    tokenIds.map(async (tokenId): Promise<FetchResult> => {
      try {
        console.log(`🔍 Calling getWrapperData(${tokenId}) on ${contractAddress}...`);
        
        // First, get the raw return data
        console.log(`📊 Getting raw return data for token ${tokenId}...`);
        const rawData = await getRawReturnData(tokenId, contractAddress, client);
        console.log(`📊 Raw return data for token ${tokenId}: ${rawData}`);
        console.log(`📊 Raw data length: ${rawData.length} characters`);
        
        // Try to parse the data with corrected ABI
        try {
          const wrapperData = await client.readContract({
            address: contractAddress,
            abi: WRAPPERS_ABI,
            functionName: 'getWrapperData',
            args: [BigInt(tokenId)]
          }) as [string, string, bigint, bigint, bigint, string, boolean];
          
          console.log(`✅ Successfully fetched data for token ${tokenId} using ABI parsing`);
          
          return {
            tokenId,
            success: true,
            data: {
              uri: wrapperData[0],
              metaKey: wrapperData[1],
              amount: wrapperData[2],
              tokenId: wrapperData[3],
              brandId: wrapperData[4],
              collection: wrapperData[5],
              active: wrapperData[6]
            }
          };
        } catch (abiError) {
          console.log(`⚠️ ABI parsing failed for token ${tokenId}, trying manual decoding...`);
          
          // Fallback to manual decoding
          const decodedData = decodeRawWrapperData(rawData);
          if (decodedData) {
            console.log(`✅ Successfully decoded data for token ${tokenId} using manual parsing`);
            return {
              tokenId,
              success: true,
              data: decodedData
            };
          } else {
            throw new Error(`Failed to decode data for token ${tokenId} using both ABI and manual parsing`);
          }
        }
      } catch (error) {
        console.log(`❌ Failed to fetch data for token ${tokenId}:`);
        
        if (error instanceof Error) {
          // Parse viem error details
          if (error.message.includes('RPC Request failed')) {
            console.log(`   RPC Error: ${error.message}`);
            
            // Try to extract more details from the error
            const errorStr = error.toString();
            if (errorStr.includes('stack underflow')) {
              console.log(`   Reason: Contract doesn't exist or is not deployed at this address`);
              console.log(`   This usually means the contract address is incorrect or the contract hasn't been deployed`);
            } else if (errorStr.includes('execution reverted')) {
              console.log(`   Reason: Contract call reverted - likely WrapperNotFound error`);
            } else {
              console.log(`   Full Error: ${errorStr}`);
            }
          } else if (error.message.includes('ContractFunctionExecutionError')) {
            console.log(`   Contract Error: ${error.message}`);
          } else {
            console.log(`   Error: ${error.message}`);
          }
        } else {
          console.log(`   Unknown Error: ${error}`);
        }
        
        return {
          tokenId,
          success: false,
          error: error instanceof Error ? error.message : "Unknown error"
        };
      }
    })
  );

  // Process results
  const processedResults: FetchResult[] = results.map((result, index) => {
    if (result.status === 'fulfilled') {
      return result.value;
    } else {
      return {
        tokenId: tokenIds[index],
        success: false,
        error: result.reason instanceof Error ? result.reason.message : "Unknown error"
      };
    }
  });

  return processedResults;
}

/**
 * Formats and displays the results
 * @param results - Results from fetchWrapperData
 */
function displayResults(results: FetchResult[]): void {
  console.log("\n=== Wrapper Data Results ===\n");
  
  results.forEach((result) => {
    if (result.success && result.data) {
      console.log(`✅ Token ID ${result.tokenId}:`);
      console.log(`   Meta Key: ${result.data.metaKey}`);
      console.log(`   URI: ${result.data.uri}`);
      console.log(`   Amount: ${result.data.amount.toString()}`);
      console.log(`   Original Token ID: ${result.data.tokenId.toString()}`);
      console.log(`   Brand ID: ${result.data.brandId.toString()}`);
      console.log(`   Collection: ${result.data.collection}`);
      console.log(`   Active: ${result.data.active}`);
      console.log("");
    } else {
      console.log(`❌ Token ID ${result.tokenId}: Error - ${result.error}`);
      console.log("");
    }
  });

  // Summary
  const successful = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;
  
  console.log(`=== Summary ===`);
  console.log(`Successful: ${successful}`);
  console.log(`Failed: ${failed}`);
  console.log(`Total: ${results.length}`);
}

/**
 * Main execution function
 */
async function main(): Promise<void> {
  try {
    console.log(`🚀 Starting Wrapper Data Fetcher`);
    console.log(`Network: ${network}`);
    console.log(`Chain: ${config.chain.name} (ID: ${config.chain.id})`);
    console.log(`RPC: ${config.rpc}`);
    console.log("");

    // Get contract address from config
    console.log("📋 Loading contract address from config...");
    // const contractAddress = await addresses('Wrappers') as `0x${string}`;
    const contractAddress = '0x5C85e3b6C537E8933092c91005F6F037F8CF07f1';
    if (!contractAddress) {
      console.error("❌ Failed to get contract address from config");
      console.error("This usually means:");
      console.error("1. The deployment file doesn't exist");
      console.error("2. The contract hasn't been deployed yet");
      console.error("3. The deployment file is in a different location");
      console.error("");
      console.error("To fix this:");
      console.error("1. Deploy the contracts first: bun run script/deploy.ts");
      console.error("2. Or provide the contract address manually");
      process.exit(1);
    }

    console.log(`✅ Contract address loaded: ${contractAddress}`);
    
    // Create public client
    console.log("🔌 Creating RPC client...");
    const client = createPublicClient({
      chain: config.chain,
      transport: http(config.rpc),
    });
    console.log("✅ RPC client created");

    // Parse token IDs from command line arguments
    const tokenIdsArg = argv[3];
    if (!tokenIdsArg) {
      console.error("Usage: bun run fetch-wrapper-data.ts [network] [tokenIds]");
      console.error("Example: bun run fetch-wrapper-data.ts testnet 1,2,3,4,5");
      process.exit(1);
    }

    const tokenIds = tokenIdsArg.split(',').map(id => parseInt(id.trim())).filter(id => !isNaN(id));
    
    if (tokenIds.length === 0) {
      console.error("No valid token IDs provided");
      process.exit(1);
    }

    console.log(`📝 Token IDs to fetch: [${tokenIds.join(', ')}]`);
    console.log("");

    const results = await fetchWrapperData(tokenIds, contractAddress, client);
    displayResults(results);
  } catch (error) {
    console.error("❌ Fatal error:", error instanceof Error ? error.message : "Unknown error");
    if (error instanceof Error && error.stack) {
      console.error("Stack trace:", error.stack);
    }
    process.exit(1);
  }
}

// Run the script
main(); 