import { WASM } from './wasm.js';
import {
  renderBuffer,
  handleInput
} from './render.js';
import { Timer } from './timer.js';

export class Emulator {
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
    emulator.displayMemPtr = emulator.wasm.functions.displayMemPtr;
    emulator.renderBuffer = renderBuffer;
    emulator.run = () => {
      const memory = new Uint8Array(emulator.wasm.memory.buffer);
      console.log("Running ROM");
      emulator.timer.reset();
      let quit = false;

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
