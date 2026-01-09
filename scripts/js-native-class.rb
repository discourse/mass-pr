#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require_relative "lib/stream_and_capture"

CONTROL_CHARS = /\e\[[^\x40-\x7E]*[\x40-\x7E]/

Dir.chdir("repo")

files =
  if File.exist?("plugin.rb")
    Dir["{test,assets,admin/assets}/javascripts/**/*.js"]
  else
    Dir["{test,javascripts}/**/*.js"]
  end

if (files.empty? || files.none? { |f| File.read(f).include?(".extend") }) &&
     `git diff --name-only`.empty?
  puts "No files to transform"
  exit 0
end

puts "[js-native-class] pnpm install..."
unless system "pnpm", "install"
  puts "[js-native-class] pnpm install failed"
  exit 1
end

begin
  status, out, _ =
    stream_and_capture(
      { "NO_TELEMETRY" => "true" },
      "npx",
      "ember-native-class-codemod@4.1.1",
      "--no-classic-decorator",
      *files,
    )
  exit status.exitstatus if status.exitstatus != 0
ensure
  FileUtils.rm_rf("codemods.log")
end

puts "[js-native-class] eslint..."
unless system "pnpm", "eslint", "--fix", *files
  puts "[js-native-class] eslint failed, fix violations and re-run script"
  exit 1
end

puts "[js-native-class] prettier..."
unless system "pnpm", "prettier", "--write", "--loglevel", "error", *files
  puts "[js-native-class] prettier failed"
  exit 1
end

out.gsub!(CONTROL_CHARS, "")

changed = `git diff --name-only`
if changed.empty?
  puts "[js-native-class] No files transformed"
else
  puts "[js-native-class] Files transformed:"
  puts changed
end

if !out.match?(/\b0 ok/)
  puts "[js-native-class] Some files transformed in this run. Check them manually, then re-run to proceed"
  exit 1
end

if !out.match?(/\b0 errors/)
  puts "[js-native-class] Error in codemod. Fix it manually, then re-run to proceed"
  exit 1
end

files.each do |f|
  if File.read(f).match?(%r{(observes|on).*discourse-common/utils/decorators})
    puts "[js-native-class] File #{f} uses observes from discourse-common. Update it."
    exit 1
  end
end
