# frozen_string_literal: true

# lib/poepod/gem_processor.rb
require_relative "processor"
require "rubygems/specification"
require "git"

module Poepod
  # Processes gem files for wrapping, handling unstaged files
  class GemProcessor < Processor
    def initialize(
      gemspec_path,
      include_unstaged: false,
      exclude: [],
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

    def process
      return error_no_gemspec unless File.exist?(@gemspec_path)

      spec = load_gemspec
      return spec unless spec.is_a?(Gem::Specification)

      gem_name = spec.name
      @output_file = "#{gem_name}_wrapped.txt"
      unstaged_files = check_unstaged_files

      super()

      [true, @output_file, unstaged_files]
    end

    private

    def collect_files_to_process
      spec = load_gemspec
      files_to_include = (spec.files +
                          spec.test_files +
                          find_readme_files).uniq

      files_to_include += check_unstaged_files if @include_unstaged

      files_to_include.sort.uniq.reject do |relative_path|
        should_exclude?(File.join(@base_dir, relative_path))
      end.map do |relative_path|
        File.join(@base_dir, relative_path)
      end
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
      Dir.glob(File.join(File.dirname(@gemspec_path), "README*")).map do |path|
        Pathname.new(path).relative_path_from(
          Pathname.new(File.dirname(@gemspec_path))
        ).to_s
      end
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
