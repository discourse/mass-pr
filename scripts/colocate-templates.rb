#!/usr/bin/env ruby
require 'fileutils'

Dir.chdir("repo")

def is_core_override(component)
  if !File.exist?("../core")
    system "git", "clone", "--depth", "1", "https://github.com/discourse/discourse", "../core", exception: true
  end

  Dir.glob("../core/**/components/#{component}.{hbs,js,gjs}").any?
end

def weird_js_path(component)
  Dir.glob("./**/components/#{component}.js")&.first
end

Dir.glob("**/{discourse,admin}/templates/components/**/*.hbs").each do |template_path|
  component_name = template_path[/\/templates\/components\/(.+)\.hbs$/, 1]
  if is_core_override(component_name)
    puts "Skipping core override #{component_name}"
    next
  end

  destination = template_path.sub("/templates/components/", "/components/")
  expected_js_path = destination.sub(/\.hbs$/, ".js")
  
  puts "Moving #{template_path} to #{destination}"
  FileUtils.mkdir_p(File.dirname(destination))
  FileUtils.mv(template_path, destination)

  if !File.exist?(expected_js_path)
    if path = weird_js_path(component_name)
      puts "Moving #{path} to #{expected_js_path}..."
      FileUtils.mv(path, expected_js_path)
    else
      puts "Creating #{expected_js_path}"
      File.write(expected_js_path, <<~JS)
        import Component from "@ember/component";
        export default class extends Component {}
      JS
    end
  end
end

Dir.glob("**/templates/connectors/**/*").each do |template_path|
  next unless File.file?(template_path)
  destination = template_path.sub("/templates/connectors/", "/connectors/")
  puts "Moving #{template_path} to #{destination}"
  FileUtils.mkdir_p(File.dirname(destination))
  FileUtils.mv(template_path, destination)
end
