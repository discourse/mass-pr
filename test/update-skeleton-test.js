import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import * as fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

async function fixture(t, type) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "mass-pr-skeleton-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const workspace = path.join(root, "workspace");
  const repo = path.join(workspace, "repo");
  const bin = path.join(root, "bin");
  const log = path.join(root, "commands.jsonl");
  await fs.mkdir(repo, { recursive: true });
  await fs.mkdir(bin);
  await fs.symlink(
    fileURLToPath(new URL("../scripts", import.meta.url)),
    path.join(root, "scripts")
  );

  const files = {
    "package.json": "{}\n",
    "package-lock.json": "{}\n",
    "templates/example.hbs": "{{I18n 'example'}}\n",
    "spec/example_spec.rb":
      'require "rails_helper"\ndescribe "example", js: true do\nend\n',
    [type === "plugin"
      ? "assets/javascripts/example.js.es6"
      : "test/javascripts/example.js.es6"]: "const example = true;\n",
    [type === "plugin"
      ? "assets/stylesheets/example.scss"
      : "common/example.scss"]: ".example { color: red; }\n",
    ...(type === "plugin"
      ? { "plugin.rb": "# name: real-plugin\n# transpile_js: true\n" }
      : { "about.json": "{}\n", "test/javascripts/.hidden": "keep me\n" }),
  };
  for (const [file, contents] of Object.entries(files)) {
    await fs.mkdir(path.dirname(path.join(repo, file)), { recursive: true });
    await fs.writeFile(path.join(repo, file), contents);
  }
  execFileSync("git", ["init", "-q"], { cwd: repo });
  execFileSync("git", ["add", "."], { cwd: repo });

  // Keep package managers offline while exercising the real Bash/Ruby helpers,
  // source migrations, and the interface to the standalone updater.
  for (const command of ["pnpx", "pnpm", "bundle"]) {
    await fs.writeFile(
      path.join(bin, command),
      `#!/usr/bin/env node
const fs = require("node:fs");
const command = ${JSON.stringify(command)};
const args = process.argv.slice(2);
fs.appendFileSync(process.env.COMMAND_LOG, JSON.stringify({ command, args, cwd: process.cwd() }) + "\\n");
if (command === "pnpx") {
  if (process.env.FAIL_UPDATER) process.exit(1);
  fs.writeFileSync("package.json", '{"private":true}\\n');
  fs.writeFileSync("Gemfile", '# Current skeleton\\n');
  fs.writeFileSync("Gemfile.lock", '# Installed by updater\\n');
  fs.writeFileSync("tsconfig.json", '{"from":"updater"}\\n');
  fs.writeFileSync("stylelint.config.mjs", '// Current skeleton\\n');
  fs.mkdirSync("node_modules/vendor", { recursive: true });
  fs.writeFileSync("node_modules/vendor/untouched.js.es6", "dependency\\n");
}
`,
      { mode: 0o755 }
    );
  }

  return {
    repo,
    run(script = "update-skeleton.sh", extraEnv = {}) {
      return execFileSync("bash", [path.join(root, "scripts", script)], {
        cwd: workspace,
        env: {
          ...process.env,
          PATH: `${bin}:${process.env.PATH}`,
          COMMAND_LOG: log,
          ...extraEnv,
        },
        stdio: "pipe",
      });
    },
    async calls() {
      return (await fs.readFile(log, "utf8"))
        .trim()
        .split("\n")
        .map((line) => JSON.parse(line));
    },
  };
}

for (const type of ["theme", "plugin"]) {
  test(`${type}: updater runs first, source migrations and postprocessing still run`, async (t) => {
    const f = await fixture(t, type);
    f.run();
    const calls = await f.calls();
    assert.deepEqual(calls[0], {
      command: "pnpx",
      args: ["@discourse/update-skeleton@latest"],
      cwd: f.repo,
    });
    assert.equal(calls.filter((call) => call.command === "pnpx").length, 1);
    assert(calls.every((call) => call.cwd === f.repo));
    const commands = calls.map((call) =>
      [call.command, ...call.args].join(" ")
    );
    for (const expected of [
      "pnpm update",
      "pnpm dedupe",
      "bundle lock --add-platform ruby",
      "pnpm lint:types",
    ]) {
      assert(commands.includes(expected), `Missing ${expected}`);
    }
    for (const expected of [
      "pnpm eslint --fix",
      "pnpm prettier --write",
      "pnpm stylelint --fix",
      "bundle exec stree write",
      "bundle exec rubocop --color -A",
    ]) {
      assert(
        commands.some((command) => command.startsWith(expected)),
        `Missing ${expected}`
      );
    }
    assert(!commands.includes("pnpm install"));
    assert(!commands.includes("bundle install"));
    assert(!commands.some((command) => command.startsWith("bundle update")));
    assert.equal(
      await fs.readFile(path.join(f.repo, "templates/example.hbs"), "utf8"),
      "{{i18n 'example'}}\n"
    );
    assert.equal(
      await fs.readFile(path.join(f.repo, "spec/example_spec.rb"), "utf8"),
      '\ndescribe "example" do\nend\n'
    );
    assert.equal(
      await fs.readFile(path.join(f.repo, "tsconfig.json"), "utf8"),
      '{"from":"updater"}\n'
    );
    assert.equal(
      await fs.readFile(
        path.join(f.repo, "node_modules/vendor/untouched.js.es6"),
        "utf8"
      ),
      "dependency\n"
    );
    await fs.access(
      path.join(
        f.repo,
        type === "plugin" ? "assets/javascripts/example.js" : "test/example.js"
      )
    );
    await assert.rejects(fs.access(path.join(f.repo, "package-lock.json")), {
      code: "ENOENT",
    });
    if (type === "plugin") {
      assert.equal(
        await fs.readFile(path.join(f.repo, "plugin.rb"), "utf8"),
        "# name: real-plugin\n"
      );
    } else {
      assert.equal(
        await fs.readFile(path.join(f.repo, "test/.hidden"), "utf8"),
        "keep me\n"
      );
      await assert.rejects(fs.access(path.join(f.repo, "test/javascripts")), {
        code: "ENOENT",
      });
    }
    // Retry via the old public entry point, after test directories have moved.
    f.run("update-linting.sh");
    assert.equal(
      (await f.calls()).filter((call) => call.command === "pnpx").length,
      2
    );
  });
}

test("updater failure stops mass-pr before any codemods or lint commands", async (t) => {
  const f = await fixture(t, "plugin");
  assert.throws(() => f.run("update-skeleton.sh", { FAIL_UPDATER: "1" }));
  assert.equal((await f.calls()).length, 1);
  assert.match(
    await fs.readFile(path.join(f.repo, "plugin.rb"), "utf8"),
    /transpile_js: true/
  );
  await fs.access(path.join(f.repo, "assets/javascripts/example.js.es6"));
});
