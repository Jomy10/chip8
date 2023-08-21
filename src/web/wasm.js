
import {
  initScreen,
  deinitScreen,
  setPixel,
} from './render.js';

export class WASM {
  static async init(filename) {
    let wasm = new WASM();
    wasm.obj = await loadWASM(filename, {
      env: {
        wasmlog: wasm.log.bind(wasm),
        wasmlogerr: wasm.logerr.bind(wasm),
        getTime: () => {
          return BigInt(Date.now());
        },
        wasmRand: () => {
          return Math.random() * ((8 ** 2) - 1);
        },
        initScreen: initScreen,
        deinitScreen: deinitScreen,
        setPixel: setPixel,
        // renderBuffer: renderBuffer,
        // handleInput: handleInput,
      }
    });
    wasm.memory = wasm.obj.instance.exports.memory;
    wasm.functions = wasm.obj.instance.exports;
    return wasm;
  }

  log(ptr, len) {
    console.log(this.wasmString(ptr, len));
  }

  logerr(ptr, len) {
    console.error(this.wasmString(ptr, len));
  }

  wasmString(ptr, len) {
    const memory = new Uint8Array(this.memory.buffer);
    let str = '';
    for (let i = ptr; i < ptr + len ; i++) {
      const c = String.fromCharCode(memory[i]);
      str += c;
    }
    return str;
  }
}

export const loadWASM = async (wasmFile, importObj) => {
  return await WebAssembly.instantiateStreaming(fetch(wasmFile), importObj);
};
