# lib/poepod/processor.rb
# frozen_string_literal: true

require "yaml"
require "base64"
require "marcel"
require "stringio"

module Poepod
  # Base processor class
  class Processor
    EXCLUDE_DEFAULT = [
      %r{node_modules/}, %r{.git/}, /.gitignore$/, /.DS_Store$/
    ].freeze

    def initialize(
      config_file = nil,
      include_binary: false,
      include_dot_files: false,
      exclude: nil,
      base_dir: nil
    )
      @config = load_config(config_file)
      @include_binary = include_binary
      @include_dot_files = include_dot_files
      @exclude = exclude || EXCLUDE_DEFAULT
      @base_dir = base_dir
      @failed_files = []
    end

    def process(output_file)
      files_to_process = collect_files_to_process
      total_files, copied_files = process_files(files_to_process, output_file)
      [total_files, copied_files]
    end

    private

    def process_files(files, output_file)
      total_files = files.size
      copied_files = 0

      File.open(output_file, "w", encoding: "utf-8") do |output|
        files.sort.each do |file_path|
          process_file(output, file_path)
          copied_files += 1
        end
      end

      [total_files, copied_files]
    end

    def collect_files_to_process
      raise NotImplementedError, "Subclasses must implement collect_files_to_process"
    end

    def collect_files_from_pattern(pattern)
      expanded_pattern = File.expand_path(pattern)
      expanded_pattern = File.join(expanded_pattern, "**", "*") if File.directory?(expanded_pattern)

      Dir.glob(expanded_pattern, File::FNM_DOTMATCH).each_with_object([]) do |file_path, acc|
        next unless File.file?(file_path)
        next if should_exclude?(file_path)

        acc << file_path
      end
    end

    def load_config(config_file)
      return {} unless config_file && File.exist?(config_file)

      YAML.load_file(config_file)
    end

    def binary_file?(file_path)
      return false unless File.exist?(file_path) && File.file?(file_path)

      File.open(file_path, "rb") do |file|
        content = file.read(8192) # Read first 8KB for magic byte detection
        mime_type = Marcel::MimeType.for(
          content,
          name: File.basename(file_path),
          declared_type: "text/plain"
        )

        !mime_type.start_with?("text/") && mime_type != "application/json"
      end
    end

    def process_file(output = nil, file_path)
      output ||= StringIO.new

      relative_path = if @base_dir
                        Pathname.new(file_path).relative_path_from(@base_dir).to_s
                      else
                        file_path
                      end

      puts "Adding to bundle: #{relative_path}"

      output.puts "--- START FILE: #{relative_path} ---"

      if binary_file?(file_path) && @include_binary
        output.puts encode_binary_file(file_path)
      else
        output.puts File.read(file_path)
      end

      output.puts "--- END FILE: #{relative_path} ---\n"

      output.string if output.is_a?(StringIO) # Return the string if using StringIO
    end

    def encode_binary_file(file_path)
      content = File.binread(file_path)
      mime_type = Marcel::MimeType.for(content, name: File.basename(file_path))
      encoded_content = Base64.strict_encode64(content)
      <<~HERE
        Content-Type: #{mime_type}
        Content-Transfer-Encoding: base64

        #{encoded_content}
      HERE
    end

    def dot_file?(file_path)
      File.basename(file_path).start_with?(".")
    end

    def should_exclude?(file_path)
      return true if !@include_dot_files && dot_file?(file_path)
      return true if !@include_binary && binary_file?(file_path)

      exclude_file?(file_path)
    end

    def exclude_file?(file_path)
      @exclude.any? do |pattern|
        if pattern.is_a?(Regexp)
          file_path.match?(pattern)
        else
          File.fnmatch?(pattern, file_path)
        end
      end
    end
  end
end
