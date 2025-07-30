import { resolve } from "path";
import { writeFileSync, mkdirSync, existsSync, readFileSync } from "fs";

const contracts = [
  "Roles",
  "Brands", 
  "Wrappers",
  "Whitelist",
  "Payments",
  "Sales",
  "Memberships"
];

function extractAddressesFromBroadcast(
  network: "mainnet" | "testnet"
): Record<string, string> {
  const networkId = network === "mainnet" ? "43114" : "43113";
  const broadcastPath = resolve(
    `broadcast/deploy.s.sol/${networkId}/run-latest.json`
  );

  if (!existsSync(broadcastPath)) {
    console.log(`⚠️  No broadcast file found for ${network}: ${broadcastPath}`);
    return {};
  }

  try {
    const broadcastData = JSON.parse(readFileSync(broadcastPath, "utf8"));
    const addresses: Record<string, string> = {};
    const implementationToProxy: Record<string, string> = {};

    // First, collect all implementation addresses and their corresponding proxies
    for (const tx of broadcastData.transactions) {
      if (tx.transactionType === "CREATE" && tx.contractName === "ERC1967Proxy") {
        const proxyAddress = tx.contractAddress;
        const implementationAddress = tx.arguments[0]; // First argument is the implementation address
        
        implementationToProxy[implementationAddress.toLowerCase()] = proxyAddress;
        console.log(`  Found ${network} proxy ${proxyAddress} -> implementation ${implementationAddress}`);
      }
    }

    // Now map implementation addresses to contract names and get their proxies
    for (const tx of broadcastData.transactions) {
      if (tx.transactionType === "CREATE" && tx.contractAddress) {
        const contractName = tx.contractName.toLowerCase();
        if (contractName === "roles" || 
            contractName === "brands" || 
            contractName === "wrappers" || 
            contractName === "whitelist" || 
            contractName === "payments" || 
            contractName === "sales" || 
            contractName === "memberships") {
          
          const implementationAddress = tx.contractAddress.toLowerCase();
          const proxyAddress = implementationToProxy[implementationAddress];
          
          if (proxyAddress) {
            addresses[contractName] = proxyAddress;
            console.log(`  Mapped ${network} ${contractName} implementation ${implementationAddress} -> proxy ${proxyAddress}`);
          } else {
            console.log(`  ⚠️  No proxy found for ${network} ${contractName} implementation ${implementationAddress}`);
          }
        }
      }
    }

    return addresses;
  } catch (error) {
    console.error(`Error reading broadcast file for ${network}:`, error);
    return {};
  }
}

function loadDeployments() {
  const deployments: any = { mainnet: {}, testnet: {} };

  // Extract addresses from broadcast files
  deployments.mainnet = extractAddressesFromBroadcast("mainnet");
  deployments.testnet = extractAddressesFromBroadcast("testnet");

  // Also load from existing deployment files (for manual addresses)
  const mainnetPath = resolve('deployments/mainnet/latest.json');
  if (existsSync(mainnetPath)) {
    try {
      const mainnetData = JSON.parse(readFileSync(mainnetPath, 'utf8'));
      // Merge with broadcast data, preferring broadcast data if available
      deployments.mainnet = { ...mainnetData.contracts, ...deployments.mainnet };
      console.log("  Loaded mainnet addresses from deployments file");
    } catch (error) {
      console.log("  Could not load mainnet deployments file");
    }
  }

  const testnetPath = resolve('deployments/testnet/latest.json');
  if (existsSync(testnetPath)) {
    try {
      const testnetData = JSON.parse(readFileSync(testnetPath, 'utf8'));
      // Merge with broadcast data, preferring broadcast data if available
      deployments.testnet = { ...testnetData.contracts, ...deployments.testnet };
      console.log("  Loaded testnet addresses from deployments file");
    } catch (error) {
      console.log("  Could not load testnet deployments file");
    }
  }

  return deployments;
}

async function createDeployments() {
  console.log("📁 Creating deployments folder...");
  
  const deployments = loadDeployments();
  const timestamp = new Date().toISOString();

  // Create deployments directory
  const deploymentsDir = resolve("deployments");
  if (!existsSync(deploymentsDir)) {
    mkdirSync(deploymentsDir, { recursive: true });
  }

  // Create mainnet directory
  const mainnetDir = resolve("deployments/mainnet");
  if (!existsSync(mainnetDir)) {
    mkdirSync(mainnetDir, { recursive: true });
  }

  // Create testnet directory
  const testnetDir = resolve("deployments/testnet");
  if (!existsSync(testnetDir)) {
    mkdirSync(testnetDir, { recursive: true });
  }

  // Create mainnet deployment file
  const mainnetDeployment = {
    network: "mainnet",
    chainId: 43114,
    timestamp,
    contracts: contracts.reduce((acc, contract) => {
      const addr = deployments.mainnet[contract.toLowerCase()] || "0x0000000000000000000000000000000000000000";
      acc[contract.toLowerCase()] = addr;
      return acc;
    }, {} as Record<string, string>)
  };

  writeFileSync(
    resolve("deployments/mainnet/latest.json"),
    JSON.stringify(mainnetDeployment, null, 2)
  );

  // Create testnet deployment file
  const testnetDeployment = {
    network: "testnet",
    chainId: 43113,
    timestamp,
    contracts: contracts.reduce((acc, contract) => {
      const addr = deployments.testnet[contract.toLowerCase()] || "0x0000000000000000000000000000000000000000";
      acc[contract.toLowerCase()] = addr;
      return acc;
    }, {} as Record<string, string>)
  };

  writeFileSync(
    resolve("deployments/testnet/latest.json"),
    JSON.stringify(testnetDeployment, null, 2)
  );

  // Create index file for easy access
  const deploymentsIndex = {
    mainnet: mainnetDeployment,
    testnet: testnetDeployment,
    timestamp
  };

  writeFileSync(
    resolve("deployments/index.json"),
    JSON.stringify(deploymentsIndex, null, 2)
  );

  console.log("✅ Deployments folder created successfully!");
  console.log(`📄 Created files:`);
  console.log(`  - deployments/mainnet/latest.json`);
  console.log(`  - deployments/testnet/latest.json`);
  console.log(`  - deployments/index.json`);
}

createDeployments().catch(console.error); 