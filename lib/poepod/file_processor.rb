# frozen_string_literal: true

require_relative "processor"

module Poepod
  # Processes files for concatenation, handling binary and dot files
  class FileProcessor < Processor
    def initialize(
      patterns,
      output_file,
      config_file: nil,
      include_binary: false,
      include_dot_files: false,
      exclude: nil,
      base_dir: nil
    )
      super(
        config_file,
        include_binary: include_binary,
        include_dot_files: include_dot_files,
        exclude: exclude,
        base_dir: base_dir,
      )
      @patterns = patterns
      @output_file = output_file
    end

    private

    def collect_files_to_process
      files_to_process = []

      @patterns.flatten.each do |pattern|
        expanded_pattern = File.expand_path(pattern)
        if File.directory?(expanded_pattern)
          # If the pattern is a directory, collect all files within it recursively
          files = collect_files_from_pattern(File.join(expanded_pattern, "**", "*"))
          files_to_process.concat(files)
        elsif File.file?(expanded_pattern)
          files_to_process << expanded_pattern unless should_exclude?(expanded_pattern)
        else
          # It's a pattern, collect matching files
          files = collect_files_from_pattern(expanded_pattern)
          files_to_process.concat(files)
        end
      end

      files_to_process.uniq
    end
  end
end
