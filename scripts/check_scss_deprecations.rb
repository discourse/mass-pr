#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "pathname"
require "tmpdir"
require "securerandom"
require "zlib"
require "find"
require "open3"
require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "minitar"
  gem "rubyzip"
end

if !Dir.exist?("discourse")
  puts "cloning discourse core"
  system "git",
         "clone",
         "--depth",
         "1",
         "https://github.com/discourse/discourse",
         "discourse",
         exception: true
end

Dir.chdir("discourse")

system "bundle", "install", exception: true
system "pnpm", "install", exception: true

stderr = nil

if File.exist?("../repo/plugin.rb")
  name = `basename -s '.git' $(git -C ../repo remote get-url origin)`.strip
  FileUtils.ln_s(File.absolute_path("../repo"), "plugins/#{name}")

  _, stderr, _ =
    Open3.capture3(
      { "PLUGIN_NAME" => name, "LOAD_PLUGINS" => "1" },
      "bundle",
      "exec",
      "rails",
      "runner",
      "../../scripts/support/check_scss_deprecations_script.rb",
    )

  FileUtils.rm_rf("plugins/#{name}")
else
  archive_path = "#{Pathname.new(Dir.tmpdir).realpath}/bundle_#{SecureRandom.hex}.tar.gz"

  begin
    dir = "../repo"
    sgz = Zlib::GzipWriter.new(File.open(archive_path, "wb"))
    tar = Minitar::Output.new(sgz)

    Dir.chdir(dir + "/../") do
      Find.find(File.basename(dir)) do |x|
        bn = File.basename(x)
        Find.prune if bn == "node_modules" || bn == "src" || bn[0] == "."
        next if File.directory?(x)

        Minitar.pack_file(x, tar)
      end
    end
  ensure
    tar&.close
    sgz&.close
  end

  _, stderr, _ =
    Open3.capture3(
      { "UPDATE_COMPONENTS" => "0", "THEME_ARCHIVE" => archive_path },
      "bundle",
      "exec",
      "rails",
      "runner",
      "../../scripts/support/check_scss_deprecations_script.rb",
    )
end

# check for deprecations
if stderr.include?("DEPRECATION WARNING")
  puts "\n\n⚠️ SCSS deprecations detected:\n"
  puts stderr
  puts "\n\n"
  exit 1
end
