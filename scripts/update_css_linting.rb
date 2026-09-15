#!/usr/bin/env ruby
# frozen_string_literal: true

Dir.chdir("repo")

files =
  if File.exist?("plugin.rb")
    Dir["assets/**/*.scss"]
  else
    Dir["{javascripts,desktop,mobile,common,scss,stylesheets}/**/*.scss"]
  end

if !files.any?
  puts "[update-css-linting] no scss files found"
  exit 0
end

if !system "pnpm", "stylelint", "--fix", "--allow-empty-input", *files
  puts "[update-css-linting] stylelint failed, fix violations and re-run script"
  exit 1
end
