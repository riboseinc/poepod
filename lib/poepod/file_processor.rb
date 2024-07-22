# frozen_string_literal: true

require_relative "processor"

module Poepod
  # Processes files for concatenation, handling binary and dot files
  class FileProcessor < Processor
    EXCLUDE_DEFAULT = [
      %r{node_modules/}, %r{.git/}, /.gitignore$/, /.DS_Store$/, /^\..+/
    ].freeze

    def initialize(
      files,
      output_file,
      config_file: nil,
      include_binary: false,
      include_dot_files: false,
      exclude: [],
      base_dir: nil
    )
      super(
        config_file,
        include_binary: include_binary,
        include_dot_files: include_dot_files,
        exclude: exclude,
        base_dir: base_dir,
      )
      @files = files
      @output_file = output_file
    end

    private

    def collect_files_to_process
      @files.flatten.each_with_object([]) do |file, files_to_process|
        Dir.glob(file, File::FNM_DOTMATCH).each do |matched_file|
          next unless File.file?(matched_file)
          next if should_exclude?(matched_file)

          files_to_process << matched_file
        end
      end
    end
  end
end
