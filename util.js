import { execFileSync } from "node:child_process";
import { env } from "node:process";
import readline from "readline";
import { octokit } from "./octokit.js";

export const WORKSPACE_DIR = "mass-pr-workspace";
export const SKIPPED_REPOS_PATH = `${WORKSPACE_DIR}/skipped_repos.txt`;
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

  while (typeof args.at(-1) === "object") {
    Object.assign(opts, args.pop());
  }

  if (cmd.endsWith(".rb")) {
    return execFileSync("ruby", [cmd, ...args], opts)?.trim();
  } else {
    return execFileSync(cmd, args, opts)?.trim();
  }
}

export function runInRepo(cmd, ...args) {
  return run(cmd, ...args, { cwd: `./${WORKSPACE_DIR}/repo` });
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
  return runInRepo("git", "status", "--porcelain", { encoding: "utf8" }) !== "";
}

export function createCommitIfNeeded(message) {
  if (!anyChanges()) {
    return;
  }

  runInRepo("git", "add", ".");
  runInRepo("git", "commit", "-q", "-m", `'${message}'`);
}

export function cloneRepo(repository, baseBranch, mode) {
  const url =
    mode === "ssh"
      ? `git@github.com:${repository}`
      : `https://github.com/${repository}`;

  let args = ["git", "clone", "-q", "--depth", "1"];

  if (baseBranch) {
    args.push("--branch", baseBranch);
  }

  args.push(url, `${WORKSPACE_DIR}/repo`);

  try {
    run(...args);
    return true;
  } catch {
    return false;
  }
}

export async function createPullRequest(
  owner,
  repo,
  title,
  head,
  base,
  body,
  repository
) {
  try {
    const response = await octokit.request("POST /repos/{owner}/{repo}/pulls", {
      owner,
      repo,
      title,
      head,
      base,
      body,
    });
    log(`✅ PR created for '${repository}': ${response.data.html_url}`);
  } catch (error) {
    const errorMessage = error.response?.data?.errors?.[0]?.message;

    if (errorMessage && /A pull request already exists/.test(errorMessage)) {
      log(
        `✅ PR already exists for '${repository}': https://github.com/${repository}/pulls`
      );
    } else {
      logError(error);
      throw `❓ Failed to create PR for '${repository}'`;
    }
  }
}
