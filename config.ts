import path from 'path';
import { getAddress } from 'viem';
import { avalanche, avalancheFuji } from 'viem/chains';
import { logger } from './logging/logger';

const rootDir = path.resolve(import.meta.dir, '..');

export const chainId = Bun.env.NODE_ENV === 'dev' ? avalancheFuji : avalanche;
export const RPC = Bun.env.RPC;

export async function abi(name: string) {
  try {
    const filePath = path.resolve(
      rootDir,
      'contracts',
      'out',
      `${name}.sol`,
      `${name}.json`,
    );
    const file = Bun.file(filePath);
    const payload = await file.json();

    return payload.abi;
  } catch (e) {
    logger.error(`Error loading ABI for ${name}:`, e);
  }
}

export async function addresses(name: string) {
  try {
    const nonUpgradeables = ['CruClub', 'CruToken', 'Vesting'];
    const filePath = path.resolve(
      rootDir,
      'contracts',
      'broadcast',
      'deploy.s.sol',
      chainId.id.toString(),
      'run-latest.json',
    );
    const file = Bun.file(filePath);
    const payload = await file.json();
    const transaction = payload.transactions.find(
      (x: { contractName: string }) => x.contractName === name,
    );
    if (!transaction) {
      logger.error(`No transaction found for contract ${name}`);
    }
    const nameAddress = transaction.contractAddress;

    let finalAddress;
    if (!nonUpgradeables.includes(name)) {
      const proxyTransaction = payload.transactions
        .filter(
          (x: { contractName: string }) => x.contractName === 'ERC1967Proxy',
        )
        .find(
          (x: { arguments: string[] }) =>
            x.arguments[0] === getAddress(nameAddress),
        );
      if (!proxyTransaction) {
        throw new Error(`No proxy transaction found for ${name}`);
      }
      finalAddress = proxyTransaction.contractAddress;
    } else {
      finalAddress = nameAddress;
    }

    return finalAddress;
  } catch (e) {
    logger.error(`Error looking up address for ${name}:`, e);
  }
}
