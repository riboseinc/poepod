# frozen_string_literal: true

require "yaml"
require "tqdm"
require "pathname"

module Poepod
  class Processor
    EXCLUDE_DEFAULT = [
      /node_modules\//, /.git\//, /.gitignore$/, /.DS_Store$/,
      /.jpg$/, /.jpeg$/, /.png/, /.svg$/, /.gif$/,
      /.exe$/, /.dll$/, /.so$/, /.bin$/, /.o$/, /.a$/, /.gem$/, /.cap$/,
      /.zip$/,
    ].freeze

    def initialize(config_file = nil)
      @failed_files = []
      @config = load_config(config_file)
    end

    def load_config(config_file)
      if config_file && File.exist?(config_file)
        YAML.load_file(config_file)
      else
        {}
      end
    end

    def process_file(file_path)
      content = File.read(file_path, encoding: "utf-8")
      [file_path, content, nil]
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      @failed_files << file_path
      [file_path, nil, "Failed to decode the file, as it is not saved with UTF-8 encoding."]
    end

    def gather_files(directory_path, exclude)
      exclude += @config["exclude"] if @config["exclude"]
      exclude_pattern = Regexp.union(exclude.map { |ex| Regexp.new(ex) })

      Dir.glob("#{directory_path}/**/*").reject do |file_path|
        File.directory?(file_path) || file_path.match?(exclude_pattern)
      end.map do |file_path|
        Pathname.new(file_path).expand_path.to_s
      end
    end

    def write_results_to_file(results, output_file)
      results.each_with_index do |(file_path, content, error), index|
        relative = relative_path(file_path)
        if content
          output_file.puts "--- START FILE: #{relative} ---"
          output_file.puts content
          output_file.puts "--- END FILE: #{relative} ---"
        elsif error
          output_file.puts "#{relative}\n#{error}"
        end
        output_file.puts if index < results.size - 1 # Add a newline between files
      end
    end

    def relative_path(file_path)
      Pathname.new(file_path).relative_path_from(Dir.pwd)
    end

    def write_directory_structure_to_file(directory_path, output_file_name, exclude = EXCLUDE_DEFAULT)
      dir_path = Pathname.new(directory_path)

      dir_path = dir_path.expand_path unless dir_path.absolute?

      file_list = gather_files(dir_path, exclude)
      total_files = file_list.size

      File.open(output_file_name, "w", encoding: "utf-8") do |output_file|
        results = file_list.tqdm(desc: "Progress", unit: " file").map do |file|
          process_file(file)
        end
        write_results_to_file(results, output_file)
      end

      copied_files = total_files - @failed_files.size

      [total_files, copied_files]
    end
  end
end
