#!/usr/bin/env node

import * as fs from "node:fs/promises";
import { env, exit } from "node:process";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import { octokit } from "./octokit";
import {
  anyChanges,
  cleanEnv,
  cloneRepo,
  createCommitIfNeeded,
  log,
  logError,
  run,
  runInRepo,
  waitForKeypress,
} from "./util";

export const WORKSPACE_DIR = "mass-pr-workspace";
const SKIPPED_REPOS_PATH = `${WORKSPACE_DIR}/skipped_repos.txt`;
const SCRIPT_ACTIONS = {
  q: "quit",
  s: "skip",
  p: "proceed",
  l: "lttf",
  r: "retry",
  return: "retry",
};
const ASK_ACTIONS = {
  q: "quit",
  c: "continue",
  return: "continue",
};
const DRY_RUN_ACTIONS = {
  n: "next",
  q: "quit",
};

async function waitForAction(actions) {
  while (true) {
    const action = actions[await waitForKeypress()];

    if (action) {
      return action;
    }
  }
}

async function handleScriptAction(action, repository) {
  switch (action) {
    case "quit":
      log("Quitting...");
      return exit(1);
    case "skip":
      log(`Skipping ${repository}`);
      await fs.appendFile(`./${SKIPPED_REPOS_PATH}`, `${repository}\n`);
      return "return";
    case "proceed":
      log("Making a PR anyway");
      return "break";
    case "lttf":
      log("Running lint-to-the-future...");
      runInRepo("pnpm", "lttf:ignore");
      return "continue";
    case "retry":
      log(`Retrying ${repository}`);
      return "continue";
  }
}

async function makePR({
  script,
  branch,
  baseBranch,
  body,
  message,
  mode,
  repository,
  ask,
  dryRun,
}) {
  const [owner, repoNoOwner] = repository.split("/");

  await fs.rm(`./${WORKSPACE_DIR}/repo`, { recursive: true, force: true });

  if (!cloneRepo(repository, baseBranch, mode)) {
    log(`Skipping ${repository} - the repository or the branch doesn't exist`);
    return;
  }

  baseBranch ||= runInRepo("git", "branch", "--show-current", {
    encoding: "utf8",
  });

  if (baseBranch !== branch) {
    runInRepo("git", "checkout", "-b", branch);
  }

  log(`Running '${script}' for '${repository}'...`);

  while (true) {
    try {
      run(`../${script}`, {
        cwd: `./${WORKSPACE_DIR}`,
        env: { ...cleanEnv(), PACKAGE_NAME: repository.split("/")[1] },
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

      createCommitIfNeeded("automatic changes");

      log(
        "[s] to skip this repo, [p] to make a PR anyway, [l] to run lint-to-the-future ignore, [q] to quit, [r] or [enter] to retry the script"
      );

      const action = await waitForAction(SCRIPT_ACTIONS);
      const result = await handleScriptAction(action, repository);

      createCommitIfNeeded("manual changes");

      if (result === "return") {
        return;
      } else if (result === "break") {
        break;
      } else if (result === "continue") {
        continue;
      }
    }
  }

  if (!anyChanges()) {
    log(`✅ '${repository}' is already up to date`);
  }

  if (ask) {
    log(`'${repository}' done`);
    log(
      `Review result in ./${WORKSPACE_DIR}/repo. Press [c] or [enter] to continue, or [q] to quit.`
    );
    const action = await waitForAction(ASK_ACTIONS);

    if (action === "quit") {
      log(`Exiting...`);
      exit(1);
    }
  } else if (dryRun) {
    log(`[dry-run] '${repository}' done`);
    log(
      `[dry-run] Review result in ./${WORKSPACE_DIR}/repo. Press [n] to try next repo, or [q] to quit.`
    );
    const action = await waitForAction(DRY_RUN_ACTIONS);
    if (action === "next") {
      return;
    } else {
      exit(1);
    }
  }

  if (!anyChanges()) {
    return;
  }

  log(`Updating '${branch}' branch for '${repository}'`);
  runInRepo("git", "push", "--no-progress", "-f", "origin", branch);

  // Don't create a PR when updating an existing branch
  if (baseBranch === branch) {
    return;
  }

  try {
    const response = await octokit.request("POST /repos/{owner}/{repo}/pulls", {
      owner,
      repo: repoNoOwner,
      title: message,
      head: branch,
      base: baseBranch,
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
        .option("base-branch", {
          type: "string",
          description: "Base branch used as the starting point",
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
            "A list of GitHub repositories to loop over {organization}/{repo}",
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
