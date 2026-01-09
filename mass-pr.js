#!/usr/bin/env node
/* eslint-disable no-console */

import { Octokit } from "@octokit/core";
import { throttling } from "@octokit/plugin-throttling";
import { execFileSync } from "node:child_process";
import * as fs from "node:fs/promises";
import { env, exit } from "node:process";
import readline from "readline";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";

const RETRY_COUNT = 20;
const DELAY = 5 * 60;
const WORKSPACE_DIR = "mass-pr-workspace";
const SKIPPED_REPOS_PATH = `${WORKSPACE_DIR}/skipped_repos.txt`;

const ThrottledOctokit = Octokit.plugin(throttling);

const octokit = new ThrottledOctokit({
  auth: env["GITHUB_TOKEN"],
  throttle: {
    minimumSecondaryRateRetryAfter: DELAY,

    onRateLimit: (retryAfter, options) => {
      if (options.request.retryCount < RETRY_COUNT) {
        octokit.log.warn(
          `Request quota exhausted for request ${options.method} ${options.url}`,
          `Retrying after ${retryAfter} seconds!`
        );
        return true;
      }
    },

    onSecondaryRateLimit: (retryAfter, options) => {
      if (options.request.retryCount < RETRY_COUNT) {
        octokit.log.warn(
          `Secondary rate limit hit for ${options.method} ${options.url}`,
          `Retrying after ${retryAfter} seconds!`
        );
        return true;
      }
    },
  },
});

// Workaround for @octokit/plugin-throttling bug
// See: https://github.com/octokit/plugin-throttling.js/pull/462
octokit.hook.after("request", async (response, options) => {
  if (options.request.retryCount) {
    options.request.retryCount = 0;
  }
});

function log(...message) {
  const green = "\x1b[32m";
  const reset = "\x1b[0m";
  console.log(`${green}[mass-pr]${reset}`, ...message);
}

function logError(...message) {
  const red = "\x1b[31m";
  const reset = "\x1b[0m";
  console.error(`${red}[mass-pr]${reset}`, ...message);
}

function run(cmd, ...args) {
  let opts = {
    stdio: "inherit",
  };

  if (typeof args.at(-1) === "object") {
    const extraOpts = args.pop();
    opts = {
      ...opts,
      ...extraOpts,
    };

    if (extraOpts.env) {
      opts.env = { ...env, ...extraOpts.env };
    }
  }

  if (cmd.endsWith(".rb")) {
    execFileSync("ruby", [cmd, ...args], opts);
  } else {
    execFileSync(cmd, args, opts);
  }
}

function runInRepo(cmd, ...args) {
  run(cmd, ...args, { cwd: `./${WORKSPACE_DIR}/repo` });
}

async function waitForKeypress() {
  readline.emitKeypressEvents(process.stdin);

  process.stdin.setRawMode(true);
  return new Promise((resolve) =>
    process.stdin.once("keypress", (data, key) => {
      process.stdin.setRawMode(false);
      resolve(key.name);
    })
  );
}

async function makePR({
  script,
  branch,
  body,
  message,
  mode,
  repository,
  ask,
  dryRun,
}) {
  const [owner, repoNoOwner] = repository.split("/");

  await fs.rm(`./${WORKSPACE_DIR}/repo`, { recursive: true, force: true });

  const url =
    mode === "ssh"
      ? `git@github.com:${repository}`
      : `https://github.com/${repository}`;

  run("git", "clone", "-q", "--depth", "1", url, `${WORKSPACE_DIR}/repo`);

  const defaultBranch = execFileSync(
    "git",
    ["-C", `${WORKSPACE_DIR}/repo`, "branch", "--show-current"],
    {
      encoding: "utf8",
    }
  ).trim();

  log(`Running '${script}' for '${repository}'...`);

  while (true) {
    try {
      run(`../${script}`, {
        cwd: `./${WORKSPACE_DIR}`,
        env: { PACKAGE_NAME: repository.split("/")[1] },
      });
      break;
    } catch (err) {
      log(`\nScript run failed for '${repository}'`);
      if (err.code === "ENOENT") {
        logError(`'${script}' doesn't exist`);
      }

      if (!process.stdin.isTTY) {
        throw err;
      }

      log(
        `s to skip this repo, p to make a PR anyway, q to exit, r (or any other key) to retry the script`
      );

      const key = await waitForKeypress();

      if (key === "s") {
        log(`Skipping ${repository}`);
        await fs.appendFile(`./${SKIPPED_REPOS_PATH}`, `${repository}\n`);
        return;
      } else if (key === "p") {
        log(`Making a PR anyway`);
        break;
      } else if (key === "q") {
        log(`Exiting...`);
        exit(1);
      } else {
        log(`Retrying ${repository}`);
        continue;
      }
    }
  }

  const anyChanges =
    execFileSync(
      "git",
      ["-C", `./${WORKSPACE_DIR}/repo`, "status", "--porcelain"],
      {
        encoding: "utf8",
      }
    ).trim() !== "";

  if (!anyChanges) {
    log(`✅ '${repository}' is already up to date`);
  }

  if (ask) {
    log(`'${repository}' done`);
    log(
      `Review result in ./${WORKSPACE_DIR}/repo. Press q to exit, or any other key to continue`
    );
    const key = await waitForKeypress();

    if (key === "q") {
      log(`Exiting...`);
      exit(1);
    }
  } else if (dryRun) {
    log(`[dry-run] '${repository}' done`);
    log(
      `[dry-run] Review result in ./${WORKSPACE_DIR}/repo. Press n to try next repo. Any other key to quit.`
    );
    const key = await waitForKeypress();
    if (key === "n") {
      return;
    } else {
      exit(1);
    }
  }

  if (!anyChanges) {
    return;
  }

  log(`Updating '${branch}' branch for '${repository}'`);

  runInRepo("git", "checkout", "-b", branch);
  runInRepo("git", "add", ".");
  runInRepo("git", "commit", "-q", "-m", message);
  runInRepo("git", "push", "--no-progress", "-f", "origin", branch);

  try {
    const response = await octokit.request("POST /repos/{owner}/{repo}/pulls", {
      owner,
      repo: repoNoOwner,
      title: message,
      head: branch,
      base: defaultBranch,
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
      console.error(error);
      throw `❓ Failed to create PR for '${repository}'`;
    }
  }
}

async function massPR(args) {
  await fs.rm(`./${WORKSPACE_DIR}`, { recursive: true, force: true });
  await fs.mkdir(`./${WORKSPACE_DIR}`);
  for (const repository of args.repositories) {
    await makePR({ ...args, repository });
  }
  try {
    await fs.access(`./${SKIPPED_REPOS_PATH}`);
  } catch {
    // no skipped repos so we can proceed to clean up
    await fs.rm(`./${WORKSPACE_DIR}`, { recursive: true, force: true });
  }
  log("Complete 🚀");
  exit(0);
}

yargs(hideBin(process.argv))
  .command(
    ["* <repositories..>"],
    "Runs <script> for each repository",
    (args) => {
      args
        .option("script", {
          describe:
            "Executable to run for each repository. Will be launched in a temporary working directory. The repository will be available under `./repo`.",
          demandOption: true,
        })
        .option("message", {
          alias: "m",
          type: "string",
          description: "Commit message (and PR title)",
          demandOption: true,
        })
        .option("branch", {
          alias: "b",
          type: "string",
          description: "Branch name",
          demandOption: true,
        })
        .option("body", {
          type: "string",
          description: "PR body",
        })
        .option("mode", {
          type: "string",
          description: "Use ssh or https for git operations",
          default: "ssh",
          choices: ["ssh", "https"],
        })
        .option("ask", {
          type: "boolean",
          default: false,
          description: "Pause before pushing changes to GitHub",
        })
        .option("dry-run", {
          type: "boolean",
          description: "Abort before pushing changes to GitHub",
        })
        .positional("repositories", {
          describe:
            "A list of GitHub repositories to loop over. {organization}/{repo}",
          array: true,
        });
    },
    (args) => {
      if (!env["GITHUB_TOKEN"]) {
        log("You must specify GITHUB_TOKEN to use this tool");
        exit(1);
      }
      massPR(args);
    }
  )
  .demandCommand()
  .parse();
