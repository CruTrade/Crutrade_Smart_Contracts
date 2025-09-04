/// <reference types="bun-types" />

import { argv, env } from "process";
import { createPublicClient, http, getContract, parseEventLogs } from "viem";
import { avalanche } from "viem/chains";
import { readFileSync, existsSync } from "fs";
import { resolve } from "path";

// Type definitions for events
interface ImportEvent {
  user: string;
  importData: {
    metaKey: string;
    sku: string;
    tokenId: bigint;
    wrapperId: bigint;
  }[];
  blockNumber: bigint;
  transactionHash: string;
  timestamp?: number;
}

interface ExportEvent {
  user: string;
  wrapperIds: bigint[];
  blockNumber: bigint;
  transactionHash: string;
  timestamp?: number;
}

interface MarketplaceTransferEvent {
  from: string;
  to: string;
  wrapperId: bigint;
  blockNumber: bigint;
  transactionHash: string;
  timestamp?: number;
}

interface BatchTransferEvent {
  from: string;
  to: string;
  tokenIds: bigint[];
  blockNumber: bigint;
  transactionHash: string;
  timestamp?: number;
}

interface TransferEvent {
  from: string;
  to: string;
  tokenId: bigint;
  blockNumber: bigint;
  transactionHash: string;
  timestamp?: number;
}

/**
 * Loads the Wrapper contract ABI from the built artifacts
 */
function loadWrapperABI(): any[] {
  const abiPath = resolve("out/Wrappers.sol/Wrappers.json");
  
  if (!existsSync(abiPath)) {
    throw new Error(`ABI file not found: ${abiPath}. Please run 'forge build' first.`);
  }

  try {
    const abiData = JSON.parse(readFileSync(abiPath, "utf8"));
    return abiData.abi;
  } catch (error) {
    throw new Error(`Failed to load Wrapper ABI: ${error}`);
  }
}

// Mainnet configuration
const MAINNET_CONFIG = {
  chain: avalanche,
  rpc: avalanche.rpcUrls.default.http[0],
  // You'll need to replace this with the actual mainnet Wrapper contract address
  wrapperAddress: "0x5C85e3b6C537E8933092c91005F6F037F8CF07f1" as `0x${string}` // TODO: Replace with actual address
};

/**
 * Fetches events from the Wrapper contract
 */
async function fetchWrapperEvents(
  fromBlock: bigint,
  toBlock: bigint,
  client: ReturnType<typeof createPublicClient>,
  eventTypes: string[] = []
): Promise<{
  imports: ImportEvent[];
  exports: ExportEvent[];
  marketplaceTransfers: MarketplaceTransferEvent[];
  batchTransfers: BatchTransferEvent[];
  transfers: TransferEvent[];
}> {
  console.log(`🔍 Fetching events from block ${fromBlock} to ${toBlock}...`);
  
  if (eventTypes.length > 0) {
    console.log(`📋 Filtering for event types: ${eventTypes.join(', ')}`);
  }

  // Load the Wrapper contract ABI
  const wrapperABI = loadWrapperABI();
  
  // Find event definitions in the ABI
  const importEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'Import');
  const exportEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'Export');
  const marketplaceTransferEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'MarketplaceTransfer');
  const batchTransferEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'BatchTransfer');
  const transferEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'Transfer');

  if (!importEvent || !exportEvent || !marketplaceTransferEvent || !batchTransferEvent || !transferEvent) {
    throw new Error('Required events not found in Wrapper ABI');
  }

  // Define which events to fetch based on filter
  const shouldFetchImport = eventTypes.length === 0 || eventTypes.includes('import');
  const shouldFetchExport = eventTypes.length === 0 || eventTypes.includes('export');
  const shouldFetchMarketplaceTransfer = eventTypes.length === 0 || eventTypes.includes('marketplace');
  const shouldFetchBatchTransfer = eventTypes.length === 0 || eventTypes.includes('batch');
  const shouldFetchTransfer = eventTypes.length === 0 || eventTypes.includes('transfer');

  // Fetch events based on filter
  const importLogs = shouldFetchImport ? await client.getLogs({
    address: MAINNET_CONFIG.wrapperAddress,
    event: importEvent,
    fromBlock,
    toBlock
  }) : [];

  const exportLogs = shouldFetchExport ? await client.getLogs({
    address: MAINNET_CONFIG.wrapperAddress,
    event: exportEvent,
    fromBlock,
    toBlock
  }) : [];

  const marketplaceTransferLogs = shouldFetchMarketplaceTransfer ? await client.getLogs({
    address: MAINNET_CONFIG.wrapperAddress,
    event: marketplaceTransferEvent,
    fromBlock,
    toBlock
  }) : [];

  const batchTransferLogs = shouldFetchBatchTransfer ? await client.getLogs({
    address: MAINNET_CONFIG.wrapperAddress,
    event: batchTransferEvent,
    fromBlock,
    toBlock
  }) : [];

  const transferLogs = shouldFetchTransfer ? await client.getLogs({
    address: MAINNET_CONFIG.wrapperAddress,
    event: transferEvent,
    fromBlock,
    toBlock
  }) : [];

  // Parse and enrich events with timestamps
  const imports: ImportEvent[] = await Promise.all(
    importLogs.map(async (log) => {
      const parsed = parseEventLogs({
        abi: wrapperABI,
        logs: [log]
      })[0];
      
      const block = await client.getBlock({ blockNumber: log.blockNumber });
      const args = parsed.args as any;
      
      return {
        user: args.user,
        importData: args.importData,
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
        timestamp: Number(block.timestamp)
      };
    })
  );

  const exports: ExportEvent[] = await Promise.all(
    exportLogs.map(async (log) => {
      const parsed = parseEventLogs({
        abi: wrapperABI,
        logs: [log]
      })[0];
      
      const block = await client.getBlock({ blockNumber: log.blockNumber });
      const args = parsed.args as any;
      
      return {
        user: args.user,
        wrapperIds: args.wrapperIds,
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
        timestamp: Number(block.timestamp)
      };
    })
  );

  const marketplaceTransfers: MarketplaceTransferEvent[] = await Promise.all(
    marketplaceTransferLogs.map(async (log) => {
      const parsed = parseEventLogs({
        abi: wrapperABI,
        logs: [log]
      })[0];
      
      const block = await client.getBlock({ blockNumber: log.blockNumber });
      const args = parsed.args as any;
      
      return {
        from: args.from,
        to: args.to,
        wrapperId: args.wrapperId,
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
        timestamp: Number(block.timestamp)
      };
    })
  );

  const batchTransfers: BatchTransferEvent[] = await Promise.all(
    batchTransferLogs.map(async (log) => {
      const parsed = parseEventLogs({
        abi: wrapperABI,
        logs: [log]
      })[0];
      
      const block = await client.getBlock({ blockNumber: log.blockNumber });
      const args = parsed.args as any;
      
      return {
        from: args.from,
        to: args.to,
        tokenIds: args.tokenIds,
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
        timestamp: Number(block.timestamp)
      };
    })
  );

  const transfers: TransferEvent[] = await Promise.all(
    transferLogs.map(async (log) => {
      const parsed = parseEventLogs({
        abi: wrapperABI,
        logs: [log]
      })[0];
      
      const block = await client.getBlock({ blockNumber: log.blockNumber });
      const args = parsed.args as any;
      
      return {
        from: args.from,
        to: args.to,
        tokenId: args.tokenId,
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
        timestamp: Number(block.timestamp)
      };
    })
  );

  return {
    imports,
    exports,
    marketplaceTransfers,
    batchTransfers,
    transfers
  };
}

/**
 * Formats timestamp to human-readable date
 */
function formatTimestamp(timestamp: number): string {
  return new Date(timestamp * 1000).toISOString();
}

/**
 * Formats address for display
 */
function formatAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Displays events in human-readable format
 */
function displayEvents(events: {
  imports: ImportEvent[];
  exports: ExportEvent[];
  marketplaceTransfers: MarketplaceTransferEvent[];
  batchTransfers: BatchTransferEvent[];
  transfers: TransferEvent[];
}): void {
  console.log("\n=== Wrapper Contract Events ===\n");

  // Display Import events
  if (events.imports.length > 0) {
    console.log("📦 IMPORT EVENTS:");
    events.imports.forEach((event, index) => {
      console.log(`  ${index + 1}. User: ${formatAddress(event.user)}`);
      console.log(`     Time: ${formatTimestamp(event.timestamp!)}`);
      console.log(`     Block: ${event.blockNumber}`);
      console.log(`     TX: ${event.transactionHash}`);
      console.log(`     Imported ${event.importData.length} wrapper(s):`);
      event.importData.forEach((data, dataIndex) => {
        console.log(`       ${dataIndex + 1}. MetaKey: ${data.metaKey}`);
        console.log(`           SKU: ${data.sku}`);
        console.log(`           Token ID: ${data.tokenId}`);
        console.log(`           Wrapper ID: ${data.wrapperId}`);
      });
      console.log("");
    });
  }

  // Display Export events
  if (events.exports.length > 0) {
    console.log("📤 EXPORT EVENTS:");
    events.exports.forEach((event, index) => {
      console.log(`  ${index + 1}. User: ${formatAddress(event.user)}`);
      console.log(`     Time: ${formatTimestamp(event.timestamp!)}`);
      console.log(`     Block: ${event.blockNumber}`);
      console.log(`     TX: ${event.transactionHash}`);
      console.log(`     Exported ${event.wrapperIds.length} wrapper(s): ${event.wrapperIds.join(', ')}`);
      console.log("");
    });
  }

  // Display MarketplaceTransfer events
  if (events.marketplaceTransfers.length > 0) {
    console.log("🔄 MARKETPLACE TRANSFER EVENTS:");
    events.marketplaceTransfers.forEach((event, index) => {
      console.log(`  ${index + 1}. From: ${formatAddress(event.from)}`);
      console.log(`     To: ${formatAddress(event.to)}`);
      console.log(`     Wrapper ID: ${event.wrapperId}`);
      console.log(`     Time: ${formatTimestamp(event.timestamp!)}`);
      console.log(`     Block: ${event.blockNumber}`);
      console.log(`     TX: ${event.transactionHash}`);
      console.log("");
    });
  }

  // Display BatchTransfer events
  if (events.batchTransfers.length > 0) {
    console.log("📦 BATCH TRANSFER EVENTS:");
    events.batchTransfers.forEach((event, index) => {
      console.log(`  ${index + 1}. From: ${formatAddress(event.from)}`);
      console.log(`     To: ${formatAddress(event.to)}`);
      console.log(`     Time: ${formatTimestamp(event.timestamp!)}`);
      console.log(`     Block: ${event.blockNumber}`);
      console.log(`     TX: ${event.transactionHash}`);
      console.log(`     Transferred ${event.tokenIds.length} wrapper(s): ${event.tokenIds.join(', ')}`);
      console.log("");
    });
  }

  // Display Transfer events (filter out zero address transfers)
  const filteredTransfers = events.transfers.filter(event => 
    event.from !== "0x0000000000000000000000000000000000000000" && 
    event.to !== "0x0000000000000000000000000000000000000000"
  );
  
  if (filteredTransfers.length > 0) {
    console.log("🔄 TRANSFER EVENTS:");
    filteredTransfers.forEach((event, index) => {
      console.log(`  ${index + 1}. From: ${formatAddress(event.from)}`);
      console.log(`     To: ${formatAddress(event.to)}`);
      console.log(`     Token ID: ${event.tokenId}`);
      console.log(`     Time: ${formatTimestamp(event.timestamp!)}`);
      console.log(`     Block: ${event.blockNumber}`);
      console.log(`     TX: ${event.transactionHash}`);
      console.log("");
    });
  }

  // Summary
  console.log("=== SUMMARY ===");
  console.log(`Import Events: ${events.imports.length}`);
  console.log(`Export Events: ${events.exports.length}`);
  console.log(`Marketplace Transfers: ${events.marketplaceTransfers.length}`);
  console.log(`Batch Transfers: ${events.batchTransfers.length}`);
  console.log(`Transfers: ${filteredTransfers.length}`);
  console.log(`Total Events: ${events.imports.length + events.exports.length + events.marketplaceTransfers.length + events.batchTransfers.length + filteredTransfers.length}`);
}

/**
 * Gets the latest block number
 */
async function getLatestBlockNumber(client: ReturnType<typeof createPublicClient>): Promise<bigint> {
  const block = await client.getBlock();
  return block.number!;
}

/**
 * Fetches the latest N events from the Wrapper contract
 */
async function fetchLatestEvents(
  numberOfEvents: number,
  client: ReturnType<typeof createPublicClient>,
  eventTypes: string[] = []
): Promise<{
  imports: ImportEvent[];
  exports: ExportEvent[];
  marketplaceTransfers: MarketplaceTransferEvent[];
  batchTransfers: BatchTransferEvent[];
  transfers: TransferEvent[];
}> {
  console.log(`🔍 Fetching latest ${numberOfEvents} events...`);
  
  if (eventTypes.length > 0) {
    console.log(`📋 Filtering for event types: ${eventTypes.join(', ')}`);
  }

  // Load the Wrapper contract ABI
  const wrapperABI = loadWrapperABI();
  
  // Find event definitions in the ABI
  const importEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'Import');
  const exportEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'Export');
  const marketplaceTransferEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'MarketplaceTransfer');
  const batchTransferEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'BatchTransfer');
  const transferEvent = wrapperABI.find((item: any) => item.type === 'event' && item.name === 'Transfer');

  if (!importEvent || !exportEvent || !marketplaceTransferEvent || !batchTransferEvent || !transferEvent) {
    throw new Error('Required events not found in Wrapper ABI');
  }

  // Define which events to fetch based on filter
  const shouldFetchImport = eventTypes.length === 0 || eventTypes.includes('import');
  const shouldFetchExport = eventTypes.length === 0 || eventTypes.includes('export');
  const shouldFetchMarketplaceTransfer = eventTypes.length === 0 || eventTypes.includes('marketplace');
  const shouldFetchBatchTransfer = eventTypes.length === 0 || eventTypes.includes('batch');
  const shouldFetchTransfer = eventTypes.length === 0 || eventTypes.includes('transfer');

  const latestBlock = await getLatestBlockNumber(client);
  let currentBlock = latestBlock;
  const chunkSize = 1000; // Fetch 1000 blocks at a time
  const maxBlocksToSearch = 100000; // Limit search to last 100k blocks
  let blocksSearched = 0;

  const allImports: ImportEvent[] = [];
  const allExports: ExportEvent[] = [];
  const allMarketplaceTransfers: MarketplaceTransferEvent[] = [];
  const allBatchTransfers: BatchTransferEvent[] = [];
  const allTransfers: TransferEvent[] = [];

  while (
    (allImports.length + allExports.length + allMarketplaceTransfers.length + allBatchTransfers.length + allTransfers.length) < numberOfEvents &&
    blocksSearched < maxBlocksToSearch
  ) {
    const fromBlock = currentBlock - BigInt(chunkSize) + 1n;
    const toBlock = currentBlock;

    console.log(`🔍 Searching blocks ${fromBlock} to ${toBlock}...`);

    // Fetch events based on filter
    const importLogs = shouldFetchImport ? await client.getLogs({
      address: MAINNET_CONFIG.wrapperAddress,
      event: importEvent,
      fromBlock,
      toBlock
    }) : [];

    const exportLogs = shouldFetchExport ? await client.getLogs({
      address: MAINNET_CONFIG.wrapperAddress,
      event: exportEvent,
      fromBlock,
      toBlock
    }) : [];

    const marketplaceTransferLogs = shouldFetchMarketplaceTransfer ? await client.getLogs({
      address: MAINNET_CONFIG.wrapperAddress,
      event: marketplaceTransferEvent,
      fromBlock,
      toBlock
    }) : [];

    const batchTransferLogs = shouldFetchBatchTransfer ? await client.getLogs({
      address: MAINNET_CONFIG.wrapperAddress,
      event: batchTransferEvent,
      fromBlock,
      toBlock
    }) : [];

    const transferLogs = shouldFetchTransfer ? await client.getLogs({
      address: MAINNET_CONFIG.wrapperAddress,
      event: transferEvent,
      fromBlock,
      toBlock
    }) : [];

    // Parse and enrich events with timestamps
    const imports = await Promise.all(
      importLogs.map(async (log) => {
        const parsed = parseEventLogs({
          abi: wrapperABI,
          logs: [log]
        })[0];
        
        const block = await client.getBlock({ blockNumber: log.blockNumber });
        const args = parsed.args as any;
        
        return {
          user: args.user,
          importData: args.importData,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
          timestamp: Number(block.timestamp)
        };
      })
    );

    const exports = await Promise.all(
      exportLogs.map(async (log) => {
        const parsed = parseEventLogs({
          abi: wrapperABI,
          logs: [log]
        })[0];
        
        const block = await client.getBlock({ blockNumber: log.blockNumber });
        const args = parsed.args as any;
        
        return {
          user: args.user,
          wrapperIds: args.wrapperIds,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
          timestamp: Number(block.timestamp)
        };
      })
    );

    const marketplaceTransfers = await Promise.all(
      marketplaceTransferLogs.map(async (log) => {
        const parsed = parseEventLogs({
          abi: wrapperABI,
          logs: [log]
        })[0];
        
        const block = await client.getBlock({ blockNumber: log.blockNumber });
        const args = parsed.args as any;
        
        return {
          from: args.from,
          to: args.to,
          wrapperId: args.wrapperId,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
          timestamp: Number(block.timestamp)
        };
      })
    );

    const batchTransfers = await Promise.all(
      batchTransferLogs.map(async (log) => {
        const parsed = parseEventLogs({
          abi: wrapperABI,
          logs: [log]
        })[0];
        
        const block = await client.getBlock({ blockNumber: log.blockNumber });
        const args = parsed.args as any;
        
        return {
          from: args.from,
          to: args.to,
          tokenIds: args.tokenIds,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
          timestamp: Number(block.timestamp)
        };
      })
    );

    const transfers = await Promise.all(
      transferLogs.map(async (log) => {
        const parsed = parseEventLogs({
          abi: wrapperABI,
          logs: [log]
        })[0];
        
        const block = await client.getBlock({ blockNumber: log.blockNumber });
        const args = parsed.args as any;
        
        return {
          from: args.from,
          to: args.to,
          tokenId: args.tokenId,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
          timestamp: Number(block.timestamp)
        };
      })
    );

    // Add events to collections
    allImports.push(...imports);
    allExports.push(...exports);
    allMarketplaceTransfers.push(...marketplaceTransfers);
    allBatchTransfers.push(...batchTransfers);
    allTransfers.push(...transfers);

    // Move to previous chunk
    currentBlock = fromBlock - 1n;
    blocksSearched += chunkSize;

    // Stop if we've reached the beginning of the chain
    if (currentBlock < 0n) {
      break;
    }
  }

  // Sort all events by timestamp (newest first) and take the requested number
  const allEvents = [
    ...allImports.map(e => ({ ...e, type: 'import' as const })),
    ...allExports.map(e => ({ ...e, type: 'export' as const })),
    ...allMarketplaceTransfers.map(e => ({ ...e, type: 'marketplace' as const })),
    ...allBatchTransfers.map(e => ({ ...e, type: 'batch' as const })),
    ...allTransfers.map(e => ({ ...e, type: 'transfer' as const }))
  ].sort((a, b) => b.timestamp! - a.timestamp!).slice(0, numberOfEvents);

  // Reconstruct the result object
  const result = {
    imports: allEvents.filter(e => e.type === 'import').map(e => ({ ...e, type: undefined })),
    exports: allEvents.filter(e => e.type === 'export').map(e => ({ ...e, type: undefined })),
    marketplaceTransfers: allEvents.filter(e => e.type === 'marketplace').map(e => ({ ...e, type: undefined })),
    batchTransfers: allEvents.filter(e => e.type === 'batch').map(e => ({ ...e, type: undefined })),
    transfers: allEvents.filter(e => e.type === 'transfer').map(e => ({ ...e, type: undefined }))
  };

  console.log(`✅ Found ${allEvents.length} events after searching ${blocksSearched} blocks`);
  
  return result;
}

/**
 * Main execution function
 */
async function main(): Promise<void> {
  try {
    console.log(`🚀 Starting Wrapper Events Fetcher`);
    console.log(`Network: Mainnet (Avalanche)`);
    console.log(`Chain: ${MAINNET_CONFIG.chain.name} (ID: ${MAINNET_CONFIG.chain.id})`);
    console.log(`RPC: ${MAINNET_CONFIG.rpc}`);
    console.log(`Contract: ${MAINNET_CONFIG.wrapperAddress}`);
    console.log("");

    // Check if contract address is set
    if (MAINNET_CONFIG.wrapperAddress === "0x0000000000000000000000000000000000000000") {
      console.error("❌ Please set the mainnet Wrapper contract address in the script");
      console.error("Update the wrapperAddress in MAINNET_CONFIG");
      process.exit(1);
    }

    // Create public client
    console.log("🔌 Creating RPC client...");
    const client = createPublicClient({
      chain: MAINNET_CONFIG.chain,
      transport: http(MAINNET_CONFIG.rpc),
    });
    console.log("✅ RPC client created");

    // Parse arguments
    const arg1 = argv[2];
    const arg2 = argv[3];
    const arg3 = argv[4];
    
    let fromBlock: bigint;
    let toBlock: bigint;
    let eventTypes: string[] = [];

    if (!arg1) {
      console.error("Usage:");
      console.error("  bun run fetch-wrapper-events.ts [fromBlock] [toBlock] [eventTypes...]");
      console.error("  bun run fetch-wrapper-events.ts latest [numberOfBlocks] [eventTypes...]");
      console.error("  bun run fetch-wrapper-events.ts events [numberOfEvents] [eventTypes...]");
      console.error("");
      console.error("Event Types: import, export, marketplace, batch, transfer");
      console.error("");
      console.error("Examples:");
      console.error("  bun run fetch-wrapper-events.ts 1000000 1000100");
      console.error("  bun run fetch-wrapper-events.ts latest 100");
      console.error("  bun run fetch-wrapper-events.ts latest 100 import export");
      console.error("  bun run fetch-wrapper-events.ts 1000000 1000100 marketplace transfer");
      console.error("  bun run fetch-wrapper-events.ts events 10");
      console.error("  bun run fetch-wrapper-events.ts events 20 import export");
      process.exit(1);
    }

    // Parse event types (all arguments after the first two)
    const eventTypeArgs = argv.slice(4);
    if (eventTypeArgs.length > 0) {
      const validEventTypes = ['import', 'export', 'marketplace', 'batch', 'transfer'];
      eventTypes = eventTypeArgs.filter(type => validEventTypes.includes(type));
      
      if (eventTypes.length !== eventTypeArgs.length) {
        const invalidTypes = eventTypeArgs.filter(type => !validEventTypes.includes(type));
        console.warn(`⚠️  Invalid event types ignored: ${invalidTypes.join(', ')}`);
        console.warn(`Valid event types: ${validEventTypes.join(', ')}`);
      }
    }

    if (arg1 === "events") {
      // Fetch latest N events
      const numberOfEvents = arg2 ? parseInt(arg2) : 10;
      
      if (isNaN(numberOfEvents) || numberOfEvents <= 0) {
        console.error("Number of events must be a positive integer");
        process.exit(1);
      }

      if (numberOfEvents > 1000) {
        console.warn("⚠️  Requesting more than 1000 events may take a long time");
      }

      console.log(`📝 Fetching latest ${numberOfEvents} events`);
      console.log("");

      const events = await fetchLatestEvents(numberOfEvents, client, eventTypes);
      displayEvents(events);
      return;
    } else if (arg1 === "latest") {
      // Fetch from latest N blocks
      const numberOfBlocks = arg2 ? parseInt(arg2) : 100;
      
      if (isNaN(numberOfBlocks) || numberOfBlocks <= 0) {
        console.error("Number of blocks must be a positive integer");
        process.exit(1);
      }

      const latestBlock = await getLatestBlockNumber(client);
      toBlock = latestBlock;
      fromBlock = latestBlock - BigInt(numberOfBlocks) + 1n;
      
      console.log(`📝 Fetching events from latest ${numberOfBlocks} blocks (${fromBlock} to ${toBlock})`);
    } else {
      // Fetch from specific block range
      if (!arg2) {
        console.error("Usage: bun run fetch-wrapper-events.ts [fromBlock] [toBlock] [eventTypes...]");
        console.error("Example: bun run fetch-wrapper-events.ts 1000000 1000100");
        process.exit(1);
      }

      fromBlock = BigInt(arg1);
      toBlock = BigInt(arg2);
      
      if (fromBlock >= toBlock) {
        console.error("fromBlock must be less than toBlock");
        process.exit(1);
      }

      console.log(`📝 Fetching events from block ${fromBlock} to ${toBlock}`);
    }

    console.log("");

    const events = await fetchWrapperEvents(fromBlock, toBlock, client, eventTypes);
    displayEvents(events);
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