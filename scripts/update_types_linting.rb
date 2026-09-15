#!/usr/bin/env ruby
# frozen_string_literal: true

Dir.chdir("repo")

if Dir["./**/*.{js,gjs,ts,gts}"].none?
  puts "[update-types-linting] no js/gjs files found"
  exit 0
end

if !system "pnpm", "lint:types"
  puts "[update-types-linting] ember-tsc failed, fix violations and re-run script"
  exit 1
end
