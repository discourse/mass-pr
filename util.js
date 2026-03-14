import { execFileSync } from "node:child_process";
import { env } from "node:process";
import readline from "readline";
import { WORKSPACE_DIR } from "./mass-pr";

const RESET = "\x1b[0m";

export function log(...message) {
  const green = "\x1b[32m";
  // eslint-disable-next-line no-console
  console.log(`${green}[mass-pr]${RESET}`, ...message);
}

export function logError(...message) {
  const red = "\x1b[31m";
  // eslint-disable-next-line no-console
  console.error(`${red}[mass-pr]${RESET}`, ...message);
}

export function run(cmd, ...args) {
  let opts = {
    stdio: "inherit",
  };

  if (typeof args.at(-1) === "object") {
    const extraOpts = args.pop();
    opts = {
      ...opts,
      ...extraOpts,
    };
  }

  if (cmd.endsWith(".rb")) {
    execFileSync("ruby", [cmd, ...args], opts);
  } else {
    execFileSync(cmd, args, opts);
  }
}

export function runInRepo(cmd, ...args) {
  run(cmd, ...args, { cwd: `./${WORKSPACE_DIR}/repo` });
}

export async function waitForKeypress() {
  readline.emitKeypressEvents(process.stdin);

  process.stdin.setRawMode(true);
  return new Promise((resolve) =>
    process.stdin.once("keypress", (data, key) => {
      process.stdin.setRawMode(false);
      resolve(key.name);
    })
  );
}

export function cleanEnv() {
  const result = { ...env };

  // Prevent the `mass-pr` package.json from interfering with scripts
  for (const key of Object.keys(result)) {
    if (key.startsWith("npm_")) {
      delete result[key];
    }
  }

  return result;
}

export function anyChanges() {
  return (
    execFileSync(
      "git",
      ["-C", `./${WORKSPACE_DIR}/repo`, "status", "--porcelain"],
      {
        encoding: "utf8",
      }
    ).trim() !== ""
  );
}

export function createCommitIfNeeded(message) {
  if (!anyChanges()) {
    return;
  }

  runInRepo("git", "add", ".");
  runInRepo("git", "commit", "-q", "-m", message);
}
