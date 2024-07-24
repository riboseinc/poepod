# lib/poepod/file_processor.rb
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
      @patterns.flatten.each_with_object([]) do |pattern, files_to_process|
        files_to_process.concat(collect_files_from_pattern(pattern))
      end
    end
  end
end
