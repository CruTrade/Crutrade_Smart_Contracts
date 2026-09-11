import { spawn, type ChildProcess, type SpawnOptions } from 'node:child_process';
import { readFile, writeFile, rename, rm, mkdir, copyFile } from 'node:fs/promises';

const rpcUrl = 'http://127.0.0.1:8545';
const statePath = '/data/anvil.json';
const manifestPath = '/data/deployment.json';
const readyPath = '/tmp/crutrade-ready';
const admin = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
const contracts = ['Roles', 'Brands', 'Wrappers', 'Whitelist', 'Payments', 'Sales', 'Memberships', 'USDCApprovalProxy'];
type RunResult = { code?: number | null; signal?: NodeJS.Signals | null; error?: Error };
type ManagedChild = ChildProcess & { done: Promise<RunResult> };
type Manifest = { chainId: number; contracts: Record<string, string> };
type BroadcastTransaction = {
  transactionType: string;
  contractName: string;
  contractAddress: string;
  arguments?: string[];
};
let anvil: ManagedChild | undefined;
let deployment: ManagedChild | undefined;
let stopping = false;

async function rpc(method: string, params: unknown[] = []): Promise<string> {
  const response = await fetch(rpcUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
    signal: AbortSignal.timeout(3000),
  });
  if (!response.ok) throw new Error(`RPC HTTP ${response.status}`);
  const body = await response.json() as { error?: { message: string }; result?: string };
  if (body.error) throw new Error(`${method}: ${body.error.message}`);
  if (typeof body.result !== 'string') throw new Error(`${method}: invalid RPC response`);
  return body.result;
}

function run(command: string, args: string[], options: SpawnOptions = {}): ManagedChild {
  const child = spawn(command, args, { stdio: 'inherit', ...options }) as ManagedChild;
  // Attach immediately so a fast exit cannot be missed during startup.
  child.done = new Promise((resolve) => {
    child.once('error', (error) => resolve({ error }));
    child.once('exit', (code, signal) => resolve({ code, signal }));
  });
  return child;
}

async function stop() {
  stopping = true;
  await rm(readyPath, { force: true });
  if (deployment && deployment.exitCode === null) {
    deployment.kill('SIGTERM');
    await deployment.done;
  }
  if (anvil && anvil.exitCode === null) {
    anvil.kill('SIGTERM');
    await anvil.done;
  }
}

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.once(signal, () => { void stop(); });
}

async function readManifest(): Promise<Manifest | null> {
  try {
    return JSON.parse(await readFile(manifestPath, 'utf8'));
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === 'ENOENT') return null;
    throw error;
  }
}

async function verify(manifest: Manifest) {
  if (manifest.chainId !== 31337) throw new Error('Unexpected deployment chain ID');
  for (const name of contracts) {
    const address = manifest.contracts?.[name];
    if (!/^0x[0-9a-fA-F]{40}$/.test(address ?? '')) throw new Error(`Missing ${name} proxy`);
    if (await rpc('eth_getCode', [address, 'latest']) === '0x') {
      throw new Error(`Persisted ${name} proxy is missing from the chain`);
    }
  }
}

async function main() {
  await mkdir('/data', { recursive: true });
  await rm(readyPath, { force: true });
  anvil = run('anvil', ['--host', '0.0.0.0', '--port', '8545', '--chain-id', '31337',
    '--state', statePath, '--state-interval', '1', '--silent']);
  let connected = false;
  for (let attempt = 0; attempt < 60 && !stopping; attempt++) {
    if (anvil.exitCode !== null || anvil.signalCode !== null) throw new Error('Anvil exited during startup');
    try {
      connected = Number(await rpc('eth_chainId')) === 31337;
      if (connected) break;
    } catch { /* Allow the RPC listener to start. */ }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  if (stopping) return;
  if (!connected) throw new Error('Local Anvil did not become ready');

  let manifest = await readManifest();
  if (manifest) {
    await verify(manifest);
    console.log('Reusing the verified local deployment.');
  } else {
    if (Number(await rpc('eth_getTransactionCount', [admin, 'latest'])) !== 0) {
      throw new Error('Chain has transactions but no deployment manifest; inspect the volume before resetting it');
    }
    deployment = run('bun', ['script/deploy.ts', 'local'], {
      env: { ...process.env, NETWORK: 'local', PRIVATE_KEY: '', FOUNDRY_OFFLINE: 'true' },
    });
    const result = await deployment.done;
    if (stopping) return;
    if (result.error || result.code !== 0) throw new Error(`Local deployment failed: ${result.error ?? result.code}`);

    const broadcastPath = 'broadcast/deploy.s.sol/31337/run-latest.json';
    const broadcast = JSON.parse(await readFile(broadcastPath, 'utf8')) as { transactions: BroadcastTransaction[] };
    const addresses: Record<string, string> = {};
    for (const name of contracts) {
      const implementation = broadcast.transactions.find((tx) => tx.transactionType === 'CREATE' && tx.contractName === name);
      const proxy = broadcast.transactions.find((tx) => tx.transactionType === 'CREATE'
        && tx.contractName === 'ERC1967Proxy'
        && tx.arguments?.[0]?.toLowerCase() === implementation?.contractAddress?.toLowerCase());
      if (!proxy) throw new Error(`Cannot resolve ${name} proxy from broadcast`);
      addresses[name] = proxy.contractAddress;
    }
    manifest = { chainId: 31337, contracts: addresses };
    await verify(manifest);
    await copyFile(broadcastPath, '/data/broadcast.json');
    await writeFile(`${manifestPath}.tmp`, `${JSON.stringify(manifest, null, 2)}\n`);
    await rename(`${manifestPath}.tmp`, manifestPath);
  }
  if (stopping) return;
  console.log(JSON.stringify(manifest, null, 2));
  await writeFile(readyPath, 'ready\n');
  console.log('CruTrade local stack ready on port 8545 (chain 31337).');
  const result = await anvil.done;
  if (!stopping) throw new Error(`Anvil exited unexpectedly: ${result.error ?? result.code}`);
}

try {
  await main();
} catch (error) {
  console.error(error);
  process.exitCode = 1;
} finally {
  await stop();
}
