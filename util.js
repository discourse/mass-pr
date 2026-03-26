import { execFileSync, spawn } from "node:child_process";
import { env } from "node:process";
import { setTimeout as wait } from "node:timers/promises";
import readline from "readline";
import { octokit } from "./octokit.js";

export const WORKSPACE_DIR = "mass-pr-workspace";
export const SKIPPED_REPOS_PATH = `${WORKSPACE_DIR}/skipped_repos.txt`;
const MASS_PR_LABEL = "mass-pr";
const LABEL_RETRY_COUNT = 2;
const LABEL_RETRY_DELAY_MS = 2_000;
const ELLIPSIS_FRAMES = [".  ", ".. ", "...", "   "];
const ELLIPSIS_INTERVAL = 400;
const TEXT_RESET = "\x1b[0m";
const TEXT_GREEN = "\x1b[32m";
const TEXT_YELLOW = "\x1b[33m";
const TEXT_RED = "\x1b[31m";

export function log(...message) {
  // eslint-disable-next-line no-console
  console.log(`${TEXT_GREEN}[mass-pr]${TEXT_RESET}`, ...message);
}

export function logWarning(...message) {
  // eslint-disable-next-line no-console
  console.error(`${TEXT_YELLOW}[mass-pr]${TEXT_RESET}`, ...message);
}

export function logError(...message) {
  // eslint-disable-next-line no-console
  console.error(`${TEXT_RED}[mass-pr]${TEXT_RESET}`, ...message);
}

function parseRunArgs(cmd, args) {
  let opts = {};

  while (typeof args.at(-1) === "object") {
    Object.assign(opts, args.pop());
  }

  const [file, fileArgs] = cmd.endsWith(".rb")
    ? ["ruby", [cmd, ...args]]
    : [cmd, args];

  return [file, fileArgs, opts];
}

export function run(cmd, ...args) {
  const [file, fileArgs, opts] = parseRunArgs(cmd, args);

  if (!opts.encoding && !opts.stdio) {
    opts.stdio = "inherit";
  }

  const result = execFileSync(file, fileArgs, opts);
  return typeof result === "string" ? result.trim() : result;
}

export function runAsync(cmd, ...args) {
  const [file, fileArgs, opts] = parseRunArgs(cmd, args);

  return new Promise((resolve, reject) => {
    const child = spawn(file, fileArgs, opts);
    const output = [];

    child.stdout?.on("data", (chunk) => output.push(chunk));
    child.stderr?.on("data", (chunk) => output.push(chunk));

    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        const err = new Error(`Process exited with code ${code}`);
        err.output = Buffer.concat(output).toString("utf8");
        reject(err);
      }
    });
  });
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

export function anyNewCommits(baseRef = "@{upstream}") {
  return (
    runInRepo("git", "rev-list", "--max-count=1", `${baseRef}..HEAD`, {
      encoding: "utf8",
    }) !== ""
  );
}

function anyChanges() {
  return runInRepo("git", "status", "--porcelain", { encoding: "utf8" }) !== "";
}

export function createCommitIfNeeded(message) {
  if (!anyChanges()) {
    return;
  }

  runInRepo("git", "add", ".");
  runInRepo("git", "commit", "-q", "-m", message);
}

export function cloneRepo(repository, baseBranch, mode, verbose = true) {
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
    run(...args, verbose ? {} : { stdio: ["inherit", "pipe", "pipe"] });
    return true;
  } catch {
    return false;
  }
}

async function addPullRequestLabel(owner, repo, issueNumber, attempt = 0) {
  try {
    await octokit.request(
      "POST /repos/{owner}/{repo}/issues/{issue_number}/labels",
      {
        owner,
        repo,
        issue_number: issueNumber,
        labels: [MASS_PR_LABEL],
      }
    );
  } catch (error) {
    if (attempt === LABEL_RETRY_COUNT) {
      throw error;
    }

    await wait(LABEL_RETRY_DELAY_MS);
    await addPullRequestLabel(owner, repo, issueNumber, attempt + 1);
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
  let pullRequest;

  try {
    const response = await octokit.request("POST /repos/{owner}/{repo}/pulls", {
      owner,
      repo,
      title,
      head,
      base,
      body,
    });
    pullRequest = response.data;
  } catch (error) {
    const errorMessage = error.response?.data?.errors?.[0]?.message;

    if (errorMessage && /A pull request already exists/.test(errorMessage)) {
      log(
        `✅ PR already exists for ${repository}: https://github.com/${repository}/pulls`
      );
      return;
    } else {
      logError(error);
      throw `❓ Failed to create PR for ${repository}`;
    }
  }

  try {
    await addPullRequestLabel(owner, repo, pullRequest.number);
  } catch (error) {
    logError(error);
    throw `❓ Failed to add '${MASS_PR_LABEL}' label to PR for ${repository}`;
  }

  log(`✅ PR ready for ${repository}: ${pullRequest.html_url}`);
}

export async function getRepoInfo(owner, repo) {
  const { data } = await octokit.request("GET /repos/{owner}/{repo}", {
    owner,
    repo,
  });

  return { isPrivate: data.private, isArchived: data.archived };
}

export function startSpinner(prefix) {
  let i = 0;
  const frame = () =>
    `\r${prefix}${ELLIPSIS_FRAMES[i++ % ELLIPSIS_FRAMES.length]}\n`;

  process.stdout.write(frame());
  const id = setInterval(
    () => process.stdout.write(`\x1b[A${frame()}`),
    ELLIPSIS_INTERVAL
  );

  return () => {
    clearInterval(id);
    process.stdout.write(`\x1b[A\r${prefix}... ${TEXT_GREEN}✔${TEXT_RESET}\n`);
  };
}

function scriptOpts(repository, isPrivate, verbose = true) {
  return {
    cwd: `./${WORKSPACE_DIR}`,
    encoding: verbose ? undefined : "utf8",
    env: {
      ...cleanEnv(),
      CLICOLOR_FORCE: "1",
      FORCE_COLOR: "1",
      PACKAGE_NAME: repository.split("/")[1],
      PRIVATE_REPO: isPrivate ? "1" : "0",
    },
  };
}

export function runScriptVerbose(repository, script, isPrivate) {
  try {
    run(`../${script}`, scriptOpts(repository, isPrivate));
    return true;
  } catch (err) {
    if (err.code === "ENOENT") {
      logError(`'${script}' doesn't exist`);
    }

    logError(`Script run failed for ${repository}`);

    if (!process.stdin.isTTY) {
      throw err;
    }

    return false;
  }
}

export async function runScriptQuiet(repository, script, isPrivate, message) {
  const stopEllipsisAnimation = startSpinner(
    `${TEXT_GREEN}[mass-pr]${TEXT_RESET} ${message}`
  );

  try {
    await runAsync(`../${script}`, scriptOpts(repository, isPrivate, false));
    stopEllipsisAnimation();
    return true;
  } catch (err) {
    stopEllipsisAnimation();

    if (err.code === "ENOENT") {
      logError(`'${script}' doesn't exist`);
    } else if (err.output) {
      process.stdout.write(err.output);
    }

    logError(`Script run failed for ${repository}`);

    if (!process.stdin.isTTY) {
      throw err;
    }

    return false;
  }
}
