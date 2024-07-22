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
      /node_modules\//, /.git\//, /.gitignore$/, /.DS_Store$/,
    ].freeze

    def initialize(files, output_file, config_file = nil, include_binary = false)
      super(config_file)
      @files = files
      @output_file = output_file
      @failed_files = []
      @include_binary = include_binary
    end

    def process
      total_files = 0
      copied_files = 0

      File.open(@output_file, "w", encoding: "utf-8") do |output|
        @files.each do |file|
          Dir.glob(file).each do |matched_file|
            if File.file?(matched_file)
              total_files += 1
              file_path, content, error = process_file(matched_file)
              if content
                output.puts "--- START FILE: #{file_path} ---"
                output.puts content
                output.puts "--- END FILE: #{file_path} ---"
                copied_files += 1
              elsif error
                output.puts "#{file_path}\n#{error}"
              end
            end
          end
        end
      end

      [total_files, copied_files]
    end

    private

    def process_file(file_path)
      if text_file?(file_path)
        content = File.read(file_path, encoding: "utf-8")
        [file_path, content, nil]
      elsif @include_binary
        content = encode_binary_file(file_path)
        [file_path, content, nil]
      else
        [file_path, nil, "Skipped binary file"]
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
