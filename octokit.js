import { Octokit } from "@octokit/core";
import { throttling } from "@octokit/plugin-throttling";
import { env } from "node:process";

const RETRY_COUNT = 20;
const DELAY = 5 * 60;

const ThrottledOctokit = Octokit.plugin(throttling);

export const octokit = new ThrottledOctokit({
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
