# frozen_string_literal: true

require_relative "processor"
require "yaml"
require "tqdm"
require "pathname"
require "open3"
require "base64"
require "mime/types"

module Poepod
  class FileProcessor < Processor
    EXCLUDE_DEFAULT = [
      %r{node_modules/}, %r{.git/}, /.gitignore$/, /.DS_Store$/, /^\..+/ # Add dot files pattern
    ].freeze

    def initialize(files, output_file, config_file = nil, include_binary = false, include_dot_files = false)
      super(config_file)
      @files = files
      @output_file = output_file
      @failed_files = []
      @include_binary = include_binary
      @include_dot_files = include_dot_files
    end

    def process
      total_files = 0
      copied_files = 0
      files_to_process = []

      @files.flatten.each do |file|
        Dir.glob(file, File::FNM_DOTMATCH).each do |matched_file|
          next unless File.file?(matched_file)
          next if dot_file?(matched_file) && !@include_dot_files

          files_to_process << matched_file
          total_files += 1
        end
      end

      File.open(@output_file, "w", encoding: "utf-8") do |output|
        files_to_process.sort.each do |file_path|
          file_path, content, error = process_file(file_path)
          if content
            output.puts "--- START FILE: #{file_path} ---"
            output.puts content
            output.puts "--- END FILE: #{file_path} ---"
            copied_files += 1
          elsif error
            warn "ERROR: #{file_path}: #{error}"
          end
        end
      end

      [total_files, copied_files]
    end

    private

    def dot_file?(file_path)
      File.basename(file_path).start_with?(".")
    end

    def process_file(file_path)
      if text_file?(file_path)
        content = File.read(file_path, encoding: "utf-8")
        [file_path, content, nil]
      elsif @include_binary
        content = encode_binary_file(file_path)
        [file_path, content, nil]
      else
        # Skipped binary file
        [file_path, nil, nil]
      end
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      @failed_files << file_path
      [file_path, nil, "Failed to decode the file, as it is not saved with UTF-8 encoding."]
    end

    def text_file?(file_path)
      stdout, status = Open3.capture2("file", "-b", "--mime-type", file_path)
      status.success? && stdout.strip.start_with?("text/")
    end

    def encode_binary_file(file_path)
      mime_type = MIME::Types.type_for(file_path).first.content_type
      encoded_content = Base64.strict_encode64(File.binread(file_path))
      "Content-Type: #{mime_type}\nContent-Transfer-Encoding: base64\n\n#{encoded_content}"
    end
  end
end
