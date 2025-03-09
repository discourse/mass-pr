#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

Dir.chdir("repo")

# Copy the config from skeleton if it does not already exist
if !File.exist?("stylelint.config.mjs")
  FileUtils.cp("../discourse-plugin-skeleton/stylelint.config.mjs", ".")
end

files =
  if File.exist?("plugin.rb")
    Dir["assets/**/*.scss"]
  else
    Dir["{javascripts,desktop,mobile,common,scss}/**/*.scss"]
  end

if !files.any?
  puts "[update-css-linting] no scss files found"
  exit 0
end

if !system "pnpm", "stylelint", "--fix", "--allow-empty-input", *files
  puts "[update-css-linting] stylelint failed, fix violations and re-run script"
  exit 1
end
