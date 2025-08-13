#!/usr/bin/env bun

import { ethers } from "ethers";
import * as fs from "fs";

// --- Config ---
const MAINNET_RPC =
  process.env.MAINNET_RPC || "https://api.avax.network/ext/bc/C/rpc";
const DEPLOYMENT_PATH = "./broadcast/deploy.s.sol/43114/run-latest.json";
const ABI_PATH = "./out/Wrappers.sol/Wrappers.json";
const CONTRACT_NAME = "Wrappers";
const NEW_BASE_URI =
  "https://wrapper-nfts-production.s3.eu-west-1.amazonaws.com/";

// --- Helpers ---
function getContractAddress(): string {
  const data = JSON.parse(fs.readFileSync(DEPLOYMENT_PATH, "utf8"));
  const contractOrder = [
    "Roles",
    "Brands",
    "Wrappers",
    "Whitelist",
    "Payments",
    "Sales",
    "Memberships",
  ];
  const proxyAddresses: string[] = [];
  for (const tx of data.transactions) {
    if (tx.transactionType === "CREATE" && tx.contractName === "ERC1967Proxy") {
      proxyAddresses.push(tx.contractAddress);
    }
  }
  const idx = contractOrder.indexOf(CONTRACT_NAME);
  if (idx >= 0 && idx < proxyAddresses.length) {
    return proxyAddresses[idx];
  }
  const tx = data.transactions.find(
    (t: any) => t.contractName === CONTRACT_NAME
  );
  if (tx) return tx.contractAddress;
  throw new Error(
    `Could not find ${CONTRACT_NAME} address in deployment file.`
  );
}

function getABI(): any {
  const artifact = JSON.parse(fs.readFileSync(ABI_PATH, "utf8"));
  return artifact.abi;
}

// --- Main ---
async function main() {
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error("Set your OWNER private key in PRIVATE_KEY env var.");
    process.exit(1);
  }
  const provider = new ethers.JsonRpcProvider(MAINNET_RPC);
  const wallet = new ethers.Wallet(privateKey, provider);
  const address = getContractAddress();
  const abi = getABI();
  const contract = new ethers.Contract(address, abi, wallet);

  const tx = await contract.setHttpsBaseURI(NEW_BASE_URI);
  console.log("Transaction sent:", tx.hash);
  await tx.wait();
  console.log("Base URI updated to:", NEW_BASE_URI);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
