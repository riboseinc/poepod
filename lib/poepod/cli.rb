# frozen_string_literal: true

require "thor"
require_relative "processor"

module Poepod
  class Cli < Thor
    desc "concat DIRECTORY OUTPUT_FILE", "Concatenate code from a directory into one text file"
    option :exclude, type: :array, default: Poepod::Processor::EXCLUDE_DEFAULT, desc: "List of patterns to exclude"
    option :config, type: :string, desc: "Path to configuration file"

    def concat(directory, output_file = nil)
      dir_path = Pathname.new(directory)

      # Check if the directory exists
      unless dir_path.directory?
        puts "Error: Directory '#{directory}' does not exist."
        exit(1)
      end

      dir_path = dir_path.expand_path unless dir_path.absolute?

      output_file ||= "#{dir_path.basename}.txt"
      output_path = dir_path.dirname.join(output_file)
      processor = Poepod::Processor.new(options[:config])
      total_files, copied_files = processor.write_directory_structure_to_file(directory, output_path, options[:exclude])

      puts "-> #{total_files} files detected in the #{dir_path.relative_path_from(Dir.pwd)} directory."
      puts "=> #{copied_files} files have been concatenated into #{Pathname.new(output_path).relative_path_from(Dir.pwd)}."
    end

    def self.exit_on_failure?
      true
    end
  end
end
