import { Emulator } from './emulator.js';

let emulator = undefined;

onmessage = (e) => {
  switch (e.type) {
    case 'init':
      emulator = await Emulator.init(60);
      break;
    case 'load-and-run':
      emulator.loadROM(e.romData);
      emulator.run();
    //   if (e.run() == 1) {
    //     console.error("Error running emulator");
    //   }
    //   break
    // default:
    //   console.error("Invalid worker message type");
  }
};
