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
