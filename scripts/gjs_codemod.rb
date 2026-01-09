#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require_relative "lib/stream_and_capture"

Dir.chdir("repo")

puts "[gjs_codemod] running for #{ENV["PACKAGE_NAME"]}..."
status, _, _ =
  stream_and_capture(
    { "PACKAGE_NAME" => ENV["PACKAGE_NAME"] },
    "pnpm",
    "dlx",
    "discourse-gjs-codemod",
  )

exit status.exitstatus if status.exitstatus != 0
