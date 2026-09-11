import { test, afterEach } from 'bun:test';
import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { readFile, writeFile, access } from 'node:fs/promises';

type ManagedChild = ChildProcess & { done: Promise<number | null> };
let child: ManagedChild;
afterEach(async () => {
  if (child?.exitCode === null) {
    child.kill('SIGTERM');
    await child.done;
  }
});

// Run only in a disposable image container: this test owns its /data and port 8545.
test('local stack deploys, persists, reuses addresses and rejects inconsistent state', async () => {
  let output = '';
  const launch = () => {
    output = '';
    child = spawn(process.execPath, ['docker/local-stack.ts'], { stdio: ['ignore', 'pipe', 'pipe'] }) as ManagedChild;
    child.stdout!.on('data', (chunk: Buffer) => { output = (output + chunk).slice(-100000); });
    child.stderr!.on('data', (chunk: Buffer) => { output = (output + chunk).slice(-100000); });
    child.done = new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('exit', (code) => resolve(code));
    });
  };
  const waitReady = async () => {
    for (let i = 0; i < 120; i++) {
      assert.equal(child.exitCode, null, output);
      try { await access('/tmp/crutrade-ready'); return; } catch { /* Startup pending. */ }
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    assert.fail(`Startup timed out: ${output}`);
  };
  const rpc = async (method: string, params: unknown[] = []): Promise<string> => {
    const response = await fetch('http://127.0.0.1:8545', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
      signal: AbortSignal.timeout(3000),
    });
    const body = await response.json() as { error?: unknown; result: string };
    assert.equal(body.error, undefined);
    return body.result;
  };

  launch();
  await waitReady();
  const manifest = JSON.parse(await readFile('/data/deployment.json', 'utf8'));
  assert.equal(manifest.chainId, 31337);
  assert.equal(Object.keys(manifest.contracts).length, 8);
  for (const address of Object.values(manifest.contracts)) {
    assert.notEqual(await rpc('eth_getCode', [address, 'latest']), '0x');
  }
  const admin = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
  const nonce = await rpc('eth_getTransactionCount', [admin, 'latest']);
  assert.ok(Number(nonce) > 0);
  child.kill('SIGTERM');
  assert.equal(await child.done, 0, output);
  assert.ok((await readFile('/data/anvil.json')).length > 0);

  launch();
  await waitReady();
  assert.match(output, /Reusing the verified local deployment/);
  assert.equal(await rpc('eth_getTransactionCount', [admin, 'latest']), nonce);
  assert.deepEqual(JSON.parse(await readFile('/data/deployment.json', 'utf8')), manifest);
  child.kill('SIGTERM');
  assert.equal(await child.done, 0, output);

  manifest.chainId = 1;
  await writeFile('/data/deployment.json', JSON.stringify(manifest));
  launch();
  assert.equal(await child.done, 1, output);
  assert.match(output, /Unexpected deployment chain ID/);
  await assert.rejects(access('/tmp/crutrade-ready'));
}, 120000);
