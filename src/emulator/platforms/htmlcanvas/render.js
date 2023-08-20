var ctx = undefined;
var size = 1;

const WIDTH = 64;
const HEIGHT = 32;
const on = "rgb(0, 0, 0)";
const off = "rgb(255, 255, 255)";

export function renderBuffer(memory, bufferPtr) {
  console.log("Rendering", bufferPtr, size);
  console.log(memory.slice(bufferPtr.value, bufferPtr.value + (64 * 32) / 8));
  ctx.moveTo(0, 0);
  for (let y = 0; y < WIDTH; y++) {
    for (let x = 0; x < HEIGHT; x++) {
      // the xth bit in the array
      const bitIndex = y * WIDTH + x;
      // the xth byte in the array
      const memIndex = bitIndex / 8;
      const bit = memory[bufferPtr.value + memIndex] & (1 << (bitIndex % 8));
      if (bit == null) {
        console.error("Couldn't find bit");
      }
      if (bit == 0) {
        ctx.fillStyle = off;
      } else {
        ctx.fillStyle = on;
      }
      ctx.fillRect(x, y, size, size);
    }
  }
}

export function handleInput(_keypadPtr) {

}

export function initScreen(_size) {
  console.log("Size of screen:", _size);
  size = _size;
  const mainCanvas = document.querySelector("#main-canvas");
  mainCanvas.innerHTML = `
  <canvas id="canvas" width="${64 * size}" height="${32 * size}" style="border-style: 'solid'; border-width: 2px; border-color: black; padding: 1rem;"></canvas>
  `;
  ctx = document.querySelector("#canvas").getContext("2d");
}

export function deinitScreen() {
  if (ctx === undefined) {
    console.error("Attempt to deinit canvas twice");
  }
  const mainCanvas = document.querySelector("#main-canvas");
  mainCanvas.innerHTML = "";
  ctx = undefined;
}
