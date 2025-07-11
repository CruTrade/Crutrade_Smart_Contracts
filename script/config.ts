import { abi, addresses } from '../config';

const mode =
  Bun.env.NODE_ENV === 'dev'
    ? '0x104e738910C6f86c69296e256DC991053BcA9904'
    : '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9';

export const config = [
  {
    name: 'fiat',
    hex: '0xd6d95ec8ff0096cc12d80d844c22f649871840100e7e4322db215d7a870846c6',
    address: '0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6',
    minBalance: mode ? 0 : 100_000,
    fillAmount: mode ? 1_000_000 : 1_000_000,
  },
  {
    name: 'operational',
    hex: '0xb0564e6f165ee6c5d845565cff3a6e9321dd47d8cc479ebdc0ef1f562f79b57b',
    address: '0x5Ad66a6D9D45a5229240D4d88d225969e10c92eC',
    minBalance: mode ? 0 : 100_000,
    fillAmount: mode ? 1_000_000 : 1_000_000,
  },
  {
    name: 'operational',
    hex: '0xb0564e6f165ee6c5d845565cff3a6e9321dd47d8cc479ebdc0ef1f562f79b57b',
    address: '0xe812BeeF1F7A62ed142835Ec2622B71AeA858085',
    minBalance: mode ? 0 : 100_000,
    fillAmount: mode ? 1_000_000 : 1_000_000,
  },
  {
    name: 'owner',
    hex: '0x6270edb7c868f86fda4adedba75108201087268ea345934db8bad688e1feb91b',
    address: '0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6',
    minBalance: mode ? 0 : 1,
    fillAmount: mode ? 0.05 : 1,
  },
  {
    name: 'pauser',
    hex: '0x539440820030c4994db4e31b6b800deafd503688728f932addfe7a410515c14c',
    address: '0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6',
    minBalance: mode ? 0 : 1,
    fillAmount: mode ? 0.05 : 1,
  },
  {
    name: 'upgrader',
    hex: '0xa615a8afb6fffcb8c6809ac0997b5c9c12b8cc97651150f14c8f6203168cff4c',
    address: '0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6',
    minBalance: mode ? 0 : 100,
    fillAmount: mode ? 0.05 : 100,
  },
  {
    name: 'treasury',
    hex: '0x06aa03964db1f7257357ef09714a5f0ca3633723df419e97015e0c7a3e83edb7',
    address: '0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6',
    minBalance: mode ? 0 : 1,
    fillAmount: mode ? 0.05 : 1,
  },




  {
    name: 'crutoken',
    hex: '0x2cdc1ea9d922ea8165eb59a07489dba2d197383a634802ac4744c065dd9d031e',
    address: await addresses('CruToken'),
    abi: await abi('CruToken'),
    delegated: false,
  },
  {
    name: 'staking',
    hex: '0x080909c18c958ce5a2d36481697824e477319323d03154ceba3b78f28a61887b',
    address: await addresses('CruClub'),
    abi: await abi('CruClub'),
    delegated: true,
  },
  {
    name: 'brands',
    hex: '0x0b176afd3b53c7ed9244ec71116a483baac2d7f61e87bcb3209330b9d5fc5faf',
    address: await addresses('Brands'),
    abi: await abi('Brands'),
    delegated: false,
  },
  {
    name: 'wrappers',
    hex: '0xd980240a559b6bb5c0108dfa65f8f32bdbac7c1bb01f49bdfab5fa0af835a23b',
    address: await addresses('Wrappers'),
    abi: await abi('Wrappers'),
    delegated: true,
  },
  {
    name: 'whitelist',
    hex: '0x0af0c3ebe77999ca20698e1ff25f812bf82409a59d21ca15a41f39e0ce9f2500',
    address: await addresses('Whitelist'),
    abi: await abi('Whitelist'),
    delegated: true,
  },
  {
    name: 'memberships',
    hex: '0xabf1e1b82970d3fd354eebcb4fbb67c9f94230c223d4e7cf75651b52d9373026',
    address: await addresses('Memberships'),
    abi: await abi('Memberships'),
    delegated: true,
  },
  {
    name: 'payments',
    hex: '0x9b545ae45cd4ae7a7160d0821c563f741a1d756c8164aa83cb13191941a1c4b3',
    address: await addresses('Payments'),
    abi: await abi('Payments'),
    delegated: true,
  },
  {
    name: 'sales',
    hex: '0xd0145825a97688df93a9c3aa4508903f3ef435656b662316106e547246a90ff1',
    address: await addresses('Sales'),
    abi: await abi('Sales'),
    delegated: true,
  },

  {
    name: 'roles',
    hex: '0x6469746f696e63756c6f00000000000000000000000000000000000000000000',
    address: await addresses('Roles'),
    abi: await abi('Roles'),
    delegated: false,
  },
  {
    name: 'vesting',
    hex: '0xe861c6d35758bfcda7457a4a9c1d4cf1dd1fd037f0e9f6261c9268f3b75a372e',
    address: await addresses('Vesting'),
    abi: await abi('Vesting'),
    delegated: false,
  },

  {
    name: 'presale',
    hex: '0x98eba5a7b13808f833eca52bd365421b449cde4b74525a6913b19b0a84be9002',
    address: await addresses('Presale'),
    abi: await abi('Presale'),
    delegated: true,
  },
  {
    name: 'drops',
    hex: '0xa7e9de3cf5ba59258a430bb6dd90b522aa8c8b1c72bc7bdb1aec379694dfd611',
    address: await addresses('Drops'),
    abi: await abi('Drops'),
    delegated: true,
  },
  {
    name: 'referrals',
    hex: '0x9124708813b6449a90bcfc0ffb6da9ec019c03a8a95cde3b69622ca6a1e46ebc',
    address: await addresses('Referrals'),
    abi: await abi('Referrals'),
    delegated: true,
  },
];
