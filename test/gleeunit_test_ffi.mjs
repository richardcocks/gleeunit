import { Ok, Error } from "./gleam.mjs";

export function rescue(f) {
  try {
    return new Ok(f());
  } catch (e) {
    return new Error(e);
  }
}

export function suppress_output(f) {
  const oldWrite = process.stdout.write;
  process.stdout.write = () => true;
  try {
    return f();
  } finally {
    process.stdout.write = oldWrite;
  }
}
