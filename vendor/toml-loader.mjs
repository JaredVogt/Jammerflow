import * as smolToml from './smol-toml.mjs';

const parse = smolToml.parse || smolToml.default?.parse;
const stringify = smolToml.stringify || smolToml.default?.stringify;

if (typeof parse === 'function') {
  const tomlGlobal = {
    parse,
    stringify: typeof stringify === 'function' ? stringify : (value) => {
      throw new Error('TOML.stringify unavailable in smol-toml bundle');
    }
  };

  window.TOML = tomlGlobal;
  window.toml = tomlGlobal;
} else {
  console.error('Failed to initialise TOML parser from smol-toml.mjs');
}
