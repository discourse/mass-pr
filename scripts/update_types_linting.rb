#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

Dir.chdir("repo")

# Copy the config from skeleton
if File.exist?("plugin.rb")
  FileUtils.cp("../discourse-plugin-skeleton/tsconfig.json", ".")
  File.write(
    "tsconfig.json",
    File.read("tsconfig.json").gsub("discourse-plugin-skeleton", ENV["PACKAGE_NAME"]),
  )
else
  FileUtils.cp("../discourse-theme-skeleton/tsconfig.json", ".")
end

if Dir["./**/*.{js,gjs}"].none?
  puts "[update-types-linting] no js/gjs files found"
  exit 0
end

if !system "pnpm", "lint:types"
  puts "[update-types-linting] ember-tsc failed, fix violations and re-run script"
  exit 1
end
