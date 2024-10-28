# frozen_string_literal: true

require_relative "processor"
require "rubygems/specification"
require "git"
require "pathname"

module Poepod
  # Processes gem files for wrapping, handling unstaged files
  class GemProcessor < Processor
    def initialize(
      gemspec_path,
      include_unstaged: false,
      exclude: nil,
      include_binary: false,
      include_dot_files: false,
      base_dir: nil,
      config_file: nil
    )
      super(
        config_file,
        include_binary: include_binary,
        include_dot_files: include_dot_files,
        exclude: exclude,
        base_dir: base_dir || File.dirname(gemspec_path),
      )
      @gemspec_path = gemspec_path
      @include_unstaged = include_unstaged
    end

    def process(output_file)
      return error_no_gemspec unless File.exist?(@gemspec_path)

      spec = load_gemspec
      return spec unless spec.is_a?(Gem::Specification)

      unstaged_files = check_unstaged_files

      super(output_file)

      [true, output_file, unstaged_files]
    end

    private

    def collect_files_to_process
      files_to_include = find_gemspec_files
      files_to_include += check_unstaged_files if @include_unstaged

      files_to_collect = []

      files_to_include.sort.uniq.each do |relative_path|
        full_path = File.join(@base_dir, relative_path)

        next if should_exclude?(full_path)

        if File.directory?(full_path)
          # Recursively collect all files under the directory
          files = collect_files_from_pattern(full_path)
          files_to_collect.concat(files)
        elsif File.file?(full_path)
          files_to_collect << full_path
        else
          # Skip if neither file nor directory
          next
        end
      end

      files_to_collect
    end

    def find_gemspec_files
      spec = load_gemspec
      executables = spec.bindir ? collect_files_from_pattern(File.join(@base_dir, spec.bindir, "*")) : []

      (spec.files + spec.test_files + find_readme_files + executables).uniq
    end

    def error_no_gemspec
      [false, "Error: The specified gemspec file '#{@gemspec_path}' does not exist."]
    end

    def load_gemspec
      Gem::Specification.load(@gemspec_path)
    rescue StandardError => e
      [false, "Error loading gemspec: #{e.message}"]
    end

    def find_readme_files
      gemspec_dir = Pathname.new(File.dirname(@gemspec_path))
      Dir.glob(gemspec_dir.join("README*")).map do |path|
        Pathname.new(path).relative_path_from(gemspec_dir).to_s
      end
    end

    def check_unstaged_files
      gem_root = File.dirname(@gemspec_path)
      git = Git.open(gem_root)

      untracked_files = git.status.untracked.keys
      modified_files = git.status.changed.keys

      (untracked_files + modified_files).select do |file|
        file.start_with?("bin/", "exe/", "lib/", "spec/", "test/")
      end
    rescue Git::GitExecuteError => e
      warn "Git error: #{e.message}. Assuming no unstaged files."
      []
    end
  end
end
