import { resolve } from "path";
import { writeFileSync, mkdirSync, existsSync, readFileSync } from "fs";

function extractGiftAddressFromBroadcast(
  network: "mainnet" | "testnet" | "fuji"
): string | null {
  const networkId = network === "mainnet" ? "43114" : "43113";
  const broadcastPath = resolve(
    `broadcast/deploy-gift.s.sol/${networkId}/run-latest.json`
  );

  if (!existsSync(broadcastPath)) {
    console.log(`⚠️  No broadcast file found for ${network}: ${broadcastPath}`);
    return null;
  }

  try {
    const broadcastData = JSON.parse(readFileSync(broadcastPath, "utf8"));
    const implementationToProxy: Record<string, string> = {};

    // First, collect all implementation addresses and their corresponding proxies
    for (const tx of broadcastData.transactions) {
      if (tx.transactionType === "CREATE" && tx.contractName === "ERC1967Proxy") {
        const proxyAddress = tx.contractAddress;
        const implementationAddress = tx.arguments[0];
        
        implementationToProxy[implementationAddress.toLowerCase()] = proxyAddress;
        console.log(`  Found ${network} Gift proxy ${proxyAddress} -> implementation ${implementationAddress}`);
      }
    }

    // Now find the Gift implementation and get its proxy
    for (const tx of broadcastData.transactions) {
      if (tx.transactionType === "CREATE" && tx.contractAddress) {
        const contractName = tx.contractName.toLowerCase();
        if (contractName === "gift") {
          const implementationAddress = tx.contractAddress.toLowerCase();
          const proxyAddress = implementationToProxy[implementationAddress];
          
          if (proxyAddress) {
            console.log(`  Mapped ${network} gift implementation ${implementationAddress} -> proxy ${proxyAddress}`);
            return proxyAddress;
          } else {
            console.log(`  ⚠️  No proxy found for ${network} gift implementation ${implementationAddress}`);
            return null;
          }
        }
      }
    }

    console.log(`  ⚠️  Gift contract not found in ${network} broadcast file`);
    return null;
  } catch (error) {
    console.error(`Error reading broadcast file for ${network}:`, error);
    return null;
  }
}

function updateDeploymentFile(
  network: "mainnet" | "testnet",
  giftAddress: string
) {
  const networkDir = resolve(`deployments/${network}`);
  const deploymentPath = resolve(`${networkDir}/latest.json`);

  if (!existsSync(networkDir)) {
    mkdirSync(networkDir, { recursive: true });
  }

  let deployment: any = {
    network,
    chainId: network === "mainnet" ? 43114 : 43113,
    timestamp: new Date().toISOString(),
    contracts: {},
  };

  if (existsSync(deploymentPath)) {
    try {
      deployment = JSON.parse(readFileSync(deploymentPath, "utf8"));
      console.log(`  Loaded existing ${network} deployment file`);
    } catch (error) {
      console.log(`  Could not load existing ${network} deployment file, creating new one`);
    }
  }

  if (!deployment.contracts) {
    deployment.contracts = {};
  }

  deployment.contracts.gift = giftAddress;
  deployment.timestamp = new Date().toISOString();

  writeFileSync(deploymentPath, JSON.stringify(deployment, null, 2));
  console.log(`  ✅ Updated ${network} deployment file with Gift address: ${giftAddress}`);
}

function updateDeploymentIndex() {
  const indexPath = resolve("deployments/index.json");
  let index: any = { timestamp: new Date().toISOString() };

  if (existsSync(indexPath)) {
    try {
      index = JSON.parse(readFileSync(indexPath, "utf8"));
    } catch (error) {
      console.log("  Could not load existing index file, creating new one");
    }
  }

  const mainnetPath = resolve("deployments/mainnet/latest.json");
  const testnetPath = resolve("deployments/testnet/latest.json");

  if (existsSync(mainnetPath)) {
    try {
      index.mainnet = JSON.parse(readFileSync(mainnetPath, "utf8"));
    } catch (error) {
      console.log("  Could not load mainnet deployment for index");
    }
  }

  if (existsSync(testnetPath)) {
    try {
      index.testnet = JSON.parse(readFileSync(testnetPath, "utf8"));
    } catch (error) {
      console.log("  Could not load testnet deployment for index");
    }
  }

  index.timestamp = new Date().toISOString();

  writeFileSync(indexPath, JSON.stringify(index, null, 2));
  console.log(`  ✅ Updated deployments index file`);
}

async function createGiftDeployments() {
  console.log("📁 Updating deployments with Gift contract addresses...");

  const mainnetGiftAddress = extractGiftAddressFromBroadcast("mainnet");
  const testnetGiftAddress = extractGiftAddressFromBroadcast("testnet") || 
                             extractGiftAddressFromBroadcast("fuji");

  if (mainnetGiftAddress) {
    updateDeploymentFile("mainnet", mainnetGiftAddress);
  } else {
    console.log("  ⚠️  No mainnet Gift address found, skipping mainnet update");
  }

  if (testnetGiftAddress) {
    updateDeploymentFile("testnet", testnetGiftAddress);
  } else {
    console.log("  ⚠️  No testnet Gift address found, skipping testnet update");
  }

  updateDeploymentIndex();

  console.log("✅ Gift deployments updated successfully!");
}

createGiftDeployments().catch(console.error);


