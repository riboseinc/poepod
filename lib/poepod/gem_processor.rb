# frozen_string_literal: true

# lib/poepod/gem_processor.rb
require_relative "processor"
require "rubygems/specification"
require "git"

module Poepod
  # Processes gem files for wrapping, handling unstaged files
  class GemProcessor < Processor
    def initialize(gemspec_path, config_file = nil, include_unstaged: false)
      super(config_file)
      @gemspec_path = gemspec_path
      @include_unstaged = include_unstaged
    end

    def process
      return error_no_gemspec unless File.exist?(@gemspec_path)

      spec = load_gemspec
      return spec unless spec.is_a?(Gem::Specification)

      gem_name = spec.name
      output_file = "#{gem_name}_wrapped.txt"
      unstaged_files = check_unstaged_files

      write_wrapped_gem(spec, output_file, unstaged_files)

      [true, output_file, unstaged_files]
    end

    private

    def error_no_gemspec
      [false, "Error: The specified gemspec file '#{@gemspec_path}' does not exist."]
    end

    def load_gemspec
      Gem::Specification.load(@gemspec_path)
    rescue StandardError => e
      [false, "Error loading gemspec: #{e.message}"]
    end

    def write_wrapped_gem(spec, output_file, unstaged_files)
      File.open(output_file, "w") do |file|
        write_header(file, spec)
        write_unstaged_warning(file, unstaged_files) if unstaged_files.any?
        write_files_content(file, spec, unstaged_files)
      end
    end

    def write_header(file, spec)
      file.puts "# Wrapped Gem: #{spec.name}"
      file.puts "## Gemspec: #{File.basename(@gemspec_path)}"
    end

    def write_unstaged_warning(file, unstaged_files)
      file.puts "\n## Warning: Unstaged Files"
      file.puts unstaged_files.sort.join("\n")
      file.puts "\nThese files are not included in the wrap unless --include-unstaged option is used."
    end

    def write_files_content(file, spec, unstaged_files)
      file.puts "\n## Files:\n"
      files_to_include = (spec.files + spec.test_files + find_readme_files).uniq
      files_to_include += unstaged_files if @include_unstaged

      files_to_include.sort.uniq.each do |relative_path|
        write_file_content(file, relative_path)
      end
    end

    def write_file_content(file, relative_path)
      full_path = File.join(File.dirname(@gemspec_path), relative_path)
      return unless File.file?(full_path)

      file.puts "--- START FILE: #{relative_path} ---"
      file.puts File.read(full_path)
      file.puts "--- END FILE: #{relative_path} ---\n\n"
    end

    def find_readme_files
      Dir.glob(File.join(File.dirname(@gemspec_path), "README*"))
         .map { |path| Pathname.new(path).relative_path_from(Pathname.new(File.dirname(@gemspec_path))).to_s }
    end

    def check_unstaged_files
      gem_root = File.dirname(@gemspec_path)
      git = Git.open(gem_root)

      untracked_files = git.status.untracked.keys
      modified_files = git.status.changed.keys

      (untracked_files + modified_files).select do |file|
        file.start_with?("lib/", "spec/", "test/")
      end
    rescue Git::GitExecuteError => e
      warn "Git error: #{e.message}. Assuming no unstaged files."
      []
    end
  end
end
