# lib/poepod/cli.rb
# frozen_string_literal: true

require "thor"
require_relative "file_processor"
require_relative "gem_processor"

module Poepod
  # Command-line interface for Poepod
  class Cli < Thor
    # Define shared options
    def self.shared_options
      option :exclude, type: :array, default: nil,
                       desc: "List of patterns to exclude"
      option :config, type: :string, desc: "Path to configuration file"
      option :include_binary, type: :boolean, default: false, desc: "Include binary files (encoded in MIME format)"
      option :include_dot_files, type: :boolean, default: false, desc: "Include dot files"
      option :output_file, type: :string, desc: "Output path"
      option :base_dir, type: :string, desc: "Base directory for relative file paths in output"
    end

    desc "concat FILES [OUTPUT_FILE]", "Concatenate specified files into one text file"
    shared_options

    def concat(*files)
      check_files(files)
      output_file = determine_output_file(files)
      base_dir = options[:base_dir] || Dir.pwd
      process_files(files, output_file, base_dir)
    end

    desc "wrap GEMSPEC_PATH", "Wrap a gem based on its gemspec file"
    shared_options
    option :include_unstaged, type: :boolean, default: false,
                              desc: "Include unstaged files from lib, spec, and test directories"

    def wrap(gemspec_path)
      base_dir = options[:base_dir] || File.dirname(gemspec_path)
      output_file = options[:output_file] || File.join(base_dir, "#{File.basename(gemspec_path, ".*")}_wrapped.txt")
      processor = Poepod::GemProcessor.new(
        gemspec_path,
        include_unstaged: options[:include_unstaged],
        exclude: options[:exclude],
        include_binary: options[:include_binary],
        include_dot_files: options[:include_dot_files],
        base_dir: base_dir,
        config_file: options[:config]
      )
      success, result, unstaged_files = processor.process(output_file)
      if success
        handle_wrap_result(success, result, unstaged_files)
      else
        puts result
        exit(1)
      end
    end

    def self.exit_on_failure?
      true
    end

    private

    def check_files(files)
      return unless files.empty?

      puts "Error: No files specified."
      exit(1)
    end

    def determine_output_file(files)
      options[:output_file] || default_output_file(files.first)
    end

    def process_files(files, output_file, base_dir)
      output_path = Pathname.new(output_file).expand_path
      processor = Poepod::FileProcessor.new(
        files,
        output_path,
        config_file: options[:config],
        include_binary: options[:include_binary],
        include_dot_files: options[:include_dot_files],
        exclude: options[:exclude],
        base_dir: base_dir
      )
      total_files, copied_files = processor.process(output_path.to_s)
      print_result(total_files, copied_files, output_path)
    end

    def print_result(total_files, copied_files, output_path)
      puts "-> #{total_files} files detected."
      puts "=> #{copied_files} files have been concatenated into #{output_path.relative_path_from(Dir.pwd)}."
    end

    def handle_wrap_result(success, result, unstaged_files)
      if success
        puts "=> The gem has been wrapped into '#{result}'."
        print_unstaged_files_warning(unstaged_files) if unstaged_files.any?
      else
        puts result
        exit(1)
      end
    end

    def print_unstaged_files_warning(unstaged_files)
      puts "\nWarning: The following files are not staged in git:"
      puts unstaged_files
      puts "\nThese files are #{options[:include_unstaged] ? "included" : "not included"} in the wrap."
      puts "Use --include-unstaged option to include these files." unless options[:include_unstaged]
    end

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
