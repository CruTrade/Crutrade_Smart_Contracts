#!/usr/bin/env bun
import { writeFileSync, readFileSync, existsSync, mkdirSync } from "fs";
import { resolve } from "path";
import { execSync } from "child_process";

const contracts = [
  "Roles",
  "Brands", 
  "Wrappers",
  "Whitelist",
  "Payments",
  "Sales",
  "Memberships",
  "USDCApprovalProxy",
] as const;

async function extractAbi(contractName: string) {
  const artifactPath = resolve(`out/${contractName}.sol/${contractName}.json`);
  if (!existsSync(artifactPath)) {
    console.log(`⚠️  No artifact found for ${contractName}: ${artifactPath}`);
    return null;
  }

  try {
    const artifact = JSON.parse(readFileSync(artifactPath, "utf8"));
    return artifact.abi;
  } catch (error) {
    console.error(`Error reading artifact for ${contractName}:`, error);
    return null;
  }
}

async function generateTypes() {
  console.log("🔧 Extracting ABIs and generating TypeChain types...");
  
  // Create temp directory for ABIs
  const tempDir = resolve("temp-abi");
  if (!existsSync(tempDir)) {
    mkdirSync(tempDir, { recursive: true });
  }

  // Extract ABIs for each contract
  for (const contract of contracts) {
    const abi = await extractAbi(contract);
    if (abi) {
      const abiPath = resolve(tempDir, `${contract}.json`);
      writeFileSync(abiPath, JSON.stringify(abi, null, 2));
      console.log(`✅ Extracted ABI for ${contract}`);
    }
  }

  // Generate TypeChain types
  console.log("📝 Generating TypeChain types...");
  try {
    execSync(`npx typechain --target ethers-v6 --out-dir types temp-abi/*.json`, {
      stdio: 'inherit',
      cwd: resolve('.')
    });
    console.log("✅ TypeChain types generated successfully!");
  } catch (error) {
    console.error("❌ Error generating TypeChain types:", error);
    return;
  }

  // Clean up temp files
  try {
    execSync(`rm -rf ${tempDir}`);
    console.log("🧹 Cleaned up temporary files");
  } catch (error) {
    console.log("⚠️  Could not clean up temp files:", error);
  }
}

generateTypes().catch(console.error); 