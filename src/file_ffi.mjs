import { Ok, Error, toList } from "./gleam.mjs";

export function fileFromOnChange(event) {
  const file = event?.target?.files?.[0];
  return file ? new Ok(file) : new Error(null);
}

export async function readBytes(file) {
  const buffer = await file.arrayBuffer();
  return toList(new Uint8Array(buffer));
}

