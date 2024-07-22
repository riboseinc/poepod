# frozen_string_literal: true

require_relative "processor"
require "yaml"
require "tqdm"
require "pathname"
require "open3"
require "base64"
require "mime/types"

module Poepod
  # Processes files for concatenation, handling binary and dot files
  class FileProcessor < Processor
    EXCLUDE_DEFAULT = [
      %r{node_modules/}, %r{.git/}, /.gitignore$/, /.DS_Store$/, /^\..+/ # Add dot files pattern
    ].freeze

    def initialize(files, output_file, config_file: nil, include_binary: false, include_dot_files: false)
      super(config_file)
      @files = files
      @output_file = output_file
      @failed_files = []
      @include_binary = include_binary
      @include_dot_files = include_dot_files
    end

    def process
      _ = 0
      copied_files = 0
      files_to_process = collect_files_to_process
      total_files = files_to_process.size

      File.open(@output_file, "w", encoding: "utf-8") do |output|
        files_to_process.sort.each do |file_path|
          process_single_file(file_path, output)
          copied_files += 1
        end
      end

      [total_files, copied_files]
    end

    private

    def collect_files_to_process
      @files.flatten.each_with_object([]) do |file, files_to_process|
        Dir.glob(file, File::FNM_DOTMATCH).each do |matched_file|
          next unless File.file?(matched_file)
          next if dot_file?(matched_file) && !@include_dot_files
          next if binary_file?(matched_file) && !@include_binary

          files_to_process << matched_file
        end
      end
    end

    def process_single_file(file_path, output)
      file_path, content, error = process_file(file_path)
      if content
        output.puts "--- START FILE: #{file_path} ---"
        output.puts content
        output.puts "--- END FILE: #{file_path} ---"
      elsif error
        warn "ERROR: #{file_path}: #{error}"
      end
    end

    def dot_file?(file_path)
      File.basename(file_path).start_with?(".")
    end

    def binary_file?(file_path)
      !text_file?(file_path)
    end

    def process_file(file_path)
      if text_file?(file_path)
        process_text_file(file_path)
      elsif @include_binary
        process_binary_file(file_path)
      else
        [file_path, nil, nil] # Skipped binary file
      end
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      handle_encoding_error(file_path)
    end

    def process_text_file(file_path)
      [file_path, File.read(file_path, encoding: "utf-8"), nil]
    end

    def process_binary_file(file_path)
      [file_path, encode_binary_file(file_path), nil]
    end

    def handle_encoding_error(file_path)
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
