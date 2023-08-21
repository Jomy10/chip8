import { WASM } from './wasm.js';
import {
  renderBuffer,
  handleInput
} from './render.js';
// import { Timer } from './timer.js';

export class Emulator {
  static async init(clockSpeed, displaySize) {
    let emulator = new Emulator();
    emulator.wasm = await WASM.init("chip8-wasm.wasm");
    emulator.ptr = emulator.wasm.functions.initEmulator(clockSpeed, displaySize);
    if (emulator.ptr == null) {
      console.error("Couldn't initialize emulator");
      return null;
    }

    // properties
    // emulator.keypadPtr = emulator.wasm.functions.keypadPtr;
    emulator.cycleDelay = (1.0 / clockSpeed) * 1_000_000_000;
    emulator.displayMemPtr = emulator.wasm.functions.displayMemPtr;
    emulator.displayMemBufferLen = emulator.wasm.functions.getDisplayMemBufferLen(emulator.ptr);

    // functions
    emulator.handleInput = handleInput;
    // emulator.renderBuffer = renderBuffer;
    emulator.getDrawFlag = emulator.wasm.functions.drawFlag;
    emulator.isKeyPressed = emulator.wasm.functions.isKeyPressed;

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
      console.info("ROM loaded successfully");
    };

    emulator.deinit = () => {
      emulator.wasm.functions.deinitEmulator(emulator.ptr);
    }

    emulator.tick = () => {
      emulator.wasm.functions.tick(emulator.ptr);
      if (emulator.getDrawFlag(emulator.ptr) == 1) {
        // const memory = new Uint8Array(emulator.wasm.memory.buffer);
        // emulator.renderBuffer(memory, emulator.displayMemPtr.value, emulator.displayMemBufferLen);
        emulator.wasm.functions.render(emulator.ptr);
      }
      
      requestAnimationFrame(emulator.tick);
    };
    
    emulator.run = () => {
      // const memory = new Uin8Array(emulator.wasm.memory.buffer);
      console.info("running rom");
      requestAnimationFrame(emulator.tick);
    };

    return emulator;
  }
}
