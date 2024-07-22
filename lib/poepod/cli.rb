# lib/poepod/cli.rb
require "thor"
require_relative "file_processor"
require_relative "gem_processor"

module Poepod
  class Cli < Thor
    desc "concat FILES [OUTPUT_FILE]", "Concatenate specified files into one text file"
    option :exclude, type: :array, default: Poepod::FileProcessor::EXCLUDE_DEFAULT, desc: "List of patterns to exclude"
    option :config, type: :string, desc: "Path to configuration file"
    option :include_binary, type: :boolean, default: false, desc: "Include binary files (encoded in MIME format)"

    def concat(*files, output_file: nil)
      if files.empty?
        puts "Error: No files specified."
        exit(1)
      end

      output_file ||= default_output_file(files.first)
      output_path = Pathname.new(output_file).expand_path

      processor = Poepod::FileProcessor.new(files, output_path, options[:config], options[:include_binary])
      total_files, copied_files = processor.process

      puts "-> #{total_files} files detected."
      puts "=> #{copied_files} files have been concatenated into #{output_path.relative_path_from(Dir.pwd)}."
    end

    desc "wrap GEMSPEC_PATH", "Wrap a gem based on its gemspec file"
    option :include_unstaged, type: :boolean, default: false, desc: "Include unstaged files from lib, spec, and test directories"

    def wrap(gemspec_path)
      processor = Poepod::GemProcessor.new(gemspec_path, nil, options[:include_unstaged])
      success, result, unstaged_files = processor.process

      if success
        puts "=> The gem has been wrapped into '#{result}'."
        if unstaged_files.any?
          puts "\nWarning: The following files are not staged in git:"
          puts unstaged_files
          puts "\nThese files are #{options[:include_unstaged] ? "included" : "not included"} in the wrap."
          puts "Use --include-unstaged option to include these files." unless options[:include_unstaged]
        end
      else
        puts result
        exit(1)
      end
    end

    def self.exit_on_failure?
      true
    end

    private

    def default_output_file(first_pattern)
      first_item = Dir.glob(first_pattern).first
      if first_item
        if File.directory?(first_item)
          "#{File.basename(first_item)}.txt"
        else
          "#{File.basename(first_item, ".*")}_concat.txt"
        end
      else
        "concatenated_output.txt"
      end
    end
  end
end
