import { Ok, Error, toList } from "./gleam.mjs";

export function fileFromOnChange(event) {
  const file = event?.target?.files?.[0];
  return file ? new Ok(file) : new Error(null);
}

export async function readBytes(file) {
  const buffer = await file.arrayBuffer();
  return toList(new Uint8Array(buffer));
}

export function registerKeyHandlers(on_keydown, on_keyup) {
  document.addEventListener('keydown', (event) => on_keydown(event.code))
  document.addEventListener('keyup', (event) => on_keyup(event.code))
}

export function createBeeper() {
  const audioCtx = new AudioContext();
  const gainNode = audioCtx.createGain();
  const oscNode = new OscillatorNode(audioCtx);

  oscNode.connect(gainNode);
  gainNode.connect(audioCtx.destination);

  oscNode.type = "triangle"
  oscNode.frequency.value = 523;
  gainNode.gain.value = 0;

  oscNode.start();

  return { gainNode, audioCtx };
}

export function startBeeper(beeper) {
  beeper.gainNode.gain.setTargetAtTime(0.1, beeper.audioCtx.currentTime, 0.010);
}

export function stopBeeper(beeper) {
  beeper.gainNode.gain.setTargetAtTime(0, beeper.audioCtx.currentTime, 0.010);
}


