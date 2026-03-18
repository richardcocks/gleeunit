import { Ok, Error } from "./gleam.mjs";

export function rescue(f) {
  try {
    return new Ok(f());
  } catch (e) {
    return new Error(e);
  }
}

export function suppress_output(f) {
  const saved = {};
  if (typeof process === "object" && process.stdout?.write) {
    saved.processWrite = process.stdout.write;
    process.stdout.write = () => true;
  }
  if (typeof Deno === "object" && Deno.stdout?.writeSync) {
    saved.denoWriteSync = Deno.stdout.writeSync;
    Deno.stdout.writeSync = () => 0;
  }
  const oldLog = console.log;
  console.log = () => {};
  try {
    return f();
  } finally {
    if (saved.processWrite) process.stdout.write = saved.processWrite;
    if (saved.denoWriteSync) Deno.stdout.writeSync = saved.denoWriteSync;
    console.log = oldLog;
  }
}
