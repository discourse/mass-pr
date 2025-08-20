# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'fileutils'
  gem 'nokogiri'
end

require 'fileutils'
require 'nokogiri'


# Initialize content for the output file
concatenated_content = ""

# Process each .html file in the current directory
Dir.glob('**/*.html') do |html_file|
  changed = false
  file_content = File.read(html_file)
  doc = Nokogiri::HTML5.fragment(file_content)

  # Extract <script type="text/discourse-plugin"> contents
  doc.css('script[type="text/discourse-plugin"]').each do |script_tag|
    concatenated_content += script_tag.content.strip + "\n"
    script_tag.remove
    changed = true
  end

  next unless changed

  # Check if the file is now whitespace-only
  modified_content = doc.to_html
  if modified_content.strip.empty?
    File.delete(html_file)
  else
    File.write(html_file, modified_content)
  end
end

if concatenated_content.size > 0 
  # Create output directory if it doesn't exist
  output_dir = 'repo/javascripts/discourse/api-initializers'
  FileUtils.mkdir_p(output_dir)

  # Output file path
  output_file = File.join(output_dir, 'init-theme.js')

  # Write the concatenated content to the output file only if it's not empty
  File.write(output_file, <<~JS)
    import { apiInitializer } from "discourse/lib/api";
    
    export default apiInitializer((api) => {
      #{concatenated_content}
    });
  JS
end

changes = `git -C ./repo status --porcelain`.strip

if changes != ""
  system("#{__dir__}/update-js-linting.sh", exception: true)
end
