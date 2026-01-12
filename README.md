# mass-pr

This tool is intended to help apply automated changes across a large number of GitHub repositories. Running mass-pr will:

1. Delete and then create a `mass-pr-workspace` directory in your current working directory

2. For each plugin:

   a) Clone default branch into `mass-pr-workspace/repo`

   b) Run specified script in the `mass-pr-workspace`. On failure, offers to skip, retry the script, or abort the mass-pr run.

   c) If there are changes, make a branch / commit / PR

3. Delete `mass-pr-workspace`

A number of discourse-specific scripts are included in `scripts/`. They will likely need to be adapted for your intended task. In general, you should
design scripts to be idempotent so that they can be retried over the same repository multiple times. For example, the rb-linting script will abort if
it encounters a Rubocop violation. The operator can manually correct the failure, retry the script, and it will run to completion.

Scripts will be launched in the `mass-pr-workspace` directory, with the repository available in the `repo` subdirectory. The `mass-pr-workspace`
directory will persist for the entire `mass-pr` run, so it can be used to cache things which may be useful for multiple repositories (e.g. skeleton
repositories).

For detailed usage instructions, run `pnpm mass-pr --help`.

For example, to run `update-linting.sh` for the `discourse-solved` and `discourse-assign` plugins, you would run:

```bash
GITHUB_TOKEN=... pnpm mass-pr \
  --message "DEV: Update linting config & dependencies" \
  --branch "update-linting" \
  --script scripts/update-linting.sh \
  discourse-solved \
  discourse-assign
```

To load the list of plugins from a text file, you could use something like:

```bash
GITHUB_TOKEN=... pnpm mass-pr \
  --message "DEV: Update linting config & dependencies" \
  --branch "update-linting" \
  --script scripts/update-linting.sh \
  $(cat plugin-list.txt)
```

> To create a GITHUB_TOKEN, follow this [guide](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic).
> Make sure this token can create PRs in the repositories you want to update.

Once the PRs have been created, you may be interested in the [mass-merge](https://github.com/discourse/mass-merge) tool.
