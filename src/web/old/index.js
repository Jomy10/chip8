import {
  renderBuffer,
  handleInput,
  initScreen,
  deinitScreen
} from './render.js';
import { Timer } from './timer.js';

class Emulator {
  static async init(clockSpeed) {
    let emulator = new Emulator();
    emulator.wasm = await WASM.init("chip8-wasm.wasm");
    emulator.ptr = emulator.wasm.functions.initEmulator(clockSpeed);
    if (emulator.ptr == null) {
      console.error("Coudn't initialize emulator");
      return null;
    }
    emulator.worker = new Worker("wasm-worker.js");
    emulator.deinit = () => {
      emulator.wasm.functions.deinitEmulator(emulator.ptr);
    };
    emulator.loadROM = (rom) => {
      console.info("loading rom", rom);
      let memory = new Uint8Array(emulator.wasm.memory.buffer);
      const ptr = emulator.wasm.functions.alloc(rom.length);
      if (ptr == null) {
        console.error("Couldn't allocate rom data");
        return;
      }

      for (let i = 0; i < rom.length; i++) {
        memory[ptr + i] = rom[i];
      }
      
      if (emulator.wasm.functions.loadROM(emulator.ptr, 0x200, rom.length) == 1) {
        emulator.wasm.functions.free(ptr);
        throw "Error loading rom";
      }

      emulator.wasm.functions.free(ptr);
    };
    emulator.keypadPtr = emulator.wasm.functions.keypadPtr;
    emulator.handleInput = handleInput; // TODO
    emulator.timer = Timer.start();
    emulator.cycleDelay = (1.0 / clockSpeed) * 1_000_000_000;
    emulator.drawFlag = emulator.wasm.functions.drawFlag;
    emulator.displayMemPtr = emulator.wasm.functions.displayMemPtr; // TODO
    emulator.renderBuffer = renderBuffer; // TODO
    emulator.tick = () => {
        const quit = emulator.handleInput(emulator.keypadPtr);
        const dt = emulator.timer.read();
        if (dt >= emulator.cycleDelay) {
          emulator.timer.reset();
          emulator.tick();
          if (emulator.drawFlag() == 1) {
            emulator.renderBuffer(memory, emulator.displayMemPtr);
          }
        }

        window.requestAnimationFrame(emulator.tick);
    };
    emulator.run = () => {
      const memory = new Uint8Array(emulator.wasm.memory.buffer);
      console.log("Running ROM");
      emulator.timer.reset();
      // let quit = false;

      window.requestAnimationFrame(emulator.tick());

      while (!quit) {
        quit = emulator.handleInput(emulator.keypadPtr);
        const dt = emulator.timer.read();

        if (dt >= emulator.cycleDelay) {
          emulator.timer.reset();

          emulator.tick();
          if (emulator.drawFlag() == 1) {
            emulator.renderBuffer(memory, emulator.displayMemPtr);
          }
        }
      }
      // if (emulator.wasm.functions.run(emulator.ptr) == 1) {
      //   throw "Error running emulator";
      // }
      
    };
    return emulator;
  }
}

class WASM {
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

const loadWASM = async (wasmFile, importObj) => {
  return await WebAssembly.instantiateStreaming(fetch(wasmFile), importObj);
};

(async () => {
  let emulator_promise = Emulator.init(60);
  // console.log("Init:", await emulator.wasm.functions.init());

  // Load HTML content
  let mainContent = document.querySelector("#main-input");
  mainContent.innerHTML = `
  <p>Select ROM file</p>
  <input type="file" id="file-selector">
  `;

  let emulator = await emulator_promise;
  console.log(emulator.ptr);
  
  // Get and read ROM file
  const fileSelector = document.querySelector("#file-selector");
  fileSelector.addEventListener('change', (event) => {
    const file = event.target.files[0];

    const reader = new FileReader();
    reader.addEventListener('load', (event) => {
      emulator.loadROM(event.target.result);
      emulator.run();
    });
    reader.readAsArrayBuffer(file);
  });

  // emulator.loadROM();
  // emulator.run();

  // emulator.deinit();
})();

