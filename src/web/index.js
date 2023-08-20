import { Emulator } from './emulator.js';

(async () => {
  let emulator_promise = Emulator.init(60, 6);
  let mainContent = document.querySelector("#main-input");
  mainContent.innerHTML = `
  <p>Select ROM file</p>
  <input type="file" id="file-selector">
  `;

  let emulator = await emulator_promise;
  console.log('emulator loaded', emulator);
  
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
})();
