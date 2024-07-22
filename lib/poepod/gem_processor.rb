# lib/poepod/gem_processor.rb
require_relative "processor"
require "rubygems/specification"
require "git"

module Poepod
  class GemProcessor < Processor
    def initialize(gemspec_path, config_file = nil, include_unstaged = false)
      super(config_file)
      @gemspec_path = gemspec_path
      @include_unstaged = include_unstaged
    end

    def process
      unless File.exist?(@gemspec_path)
        return [false, "Error: The specified gemspec file '#{@gemspec_path}' does not exist."]
      end

      begin
        spec = Gem::Specification.load(@gemspec_path)
      rescue => e
        return [false, "Error loading gemspec: #{e.message}"]
      end

      gem_name = spec.name
      output_file = "#{gem_name}_wrapped.txt"
      unstaged_files = check_unstaged_files

      File.open(output_file, "w") do |file|
        file.puts "# Wrapped Gem: #{gem_name}"
        file.puts "## Gemspec: #{File.basename(@gemspec_path)}"

        if unstaged_files.any?
          file.puts "\n## Warning: Unstaged Files"
          file.puts unstaged_files.join("\n")
          file.puts "\nThese files are not included in the wrap unless --include-unstaged option is used."
        end

        file.puts "\n## Files:\n"

        files_to_include = (spec.files + spec.test_files + find_readme_files).uniq
        files_to_include += unstaged_files if @include_unstaged

        files_to_include.uniq.each do |relative_path|
          full_path = File.join(File.dirname(@gemspec_path), relative_path)
          if File.file?(full_path)
            file.puts "--- START FILE: #{relative_path} ---"
            file.puts File.read(full_path)
            file.puts "--- END FILE: #{relative_path} ---\n\n"
          end
        end
      end

      [true, output_file, unstaged_files]
    end

    private

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
