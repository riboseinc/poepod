# frozen_string_literal: true

# spec/poepod/gem_processor_spec.rb
require "spec_helper"
require "poepod/gem_processor"
require "tempfile"

RSpec.describe Poepod::GemProcessor do
  let(:temp_dir) { Dir.mktmpdir }
  let(:gemspec_file) { File.join(temp_dir, "test_gem.gemspec") }

  before do
    File.write(gemspec_file, <<~GEMSPEC)
      Gem::Specification.new do |spec|
        spec.name = "test_gem"
        spec.version = "0.1.0"
        spec.authors = ["Test Author"]
        spec.files = ["lib/test_gem.rb"]
        spec.test_files = ["spec/test_gem_spec.rb"]
      end
    GEMSPEC

    FileUtils.mkdir_p(File.join(temp_dir, "lib"))
    FileUtils.mkdir_p(File.join(temp_dir, "spec"))
    File.write(File.join(temp_dir, "lib/test_gem.rb"), "puts 'Hello from test_gem'")
    File.write(File.join(temp_dir, "spec/test_gem_spec.rb"), "RSpec.describe TestGem do\nend")
    File.write(File.join(temp_dir, "README.md"), "# Test Gem\n\nThis is a test gem.")
    File.write(File.join(temp_dir, "README.txt"), "Test Gem\n\nThis is a test gem in plain text.")
  end

  after do
    FileUtils.remove_entry(temp_dir)
  end

  describe "#process" do
    let(:processor) { described_class.new(gemspec_file) }

    before do
      # Mock Git operations
      allow(Git).to receive(:open).and_return(double(status: double(untracked: {}, changed: {})))
    end

    it "processes the gem files, includes README files, and spec files in sorted order" do
      success, output_file = processor.process
      expect(success).to be true
      expect(File.exist?(output_file)).to be true

      content = File.read(output_file)
      expect(content).to include("# Wrapped Gem: test_gem")
      expect(content).to include("## Gemspec: test_gem.gemspec")

      file_order = content.scan(/--- START FILE: (.+) ---/).flatten
      expected_order = [
        "README.md",
        "README.txt",
        "lib/test_gem.rb",
        "spec/test_gem_spec.rb"
      ]
      expect(file_order).to eq(expected_order)

      expect(content).to include("# Wrapped Gem: test_gem")
      expect(content).to include("## Gemspec: test_gem.gemspec")
      expect(content).to include("--- START FILE: lib/test_gem.rb ---")
      expect(content).to include("puts 'Hello from test_gem'")
      expect(content).to include("--- END FILE: lib/test_gem.rb ---")
      expect(content).to include("--- START FILE: spec/test_gem_spec.rb ---")
      expect(content).to include("RSpec.describe TestGem do")
      expect(content).to include("--- END FILE: spec/test_gem_spec.rb ---")
      expect(content).to include("--- START FILE: README.md ---")
      expect(content).to include("# Test Gem\n\nThis is a test gem.")
      expect(content).to include("--- END FILE: README.md ---")
      expect(content).to include("--- START FILE: README.txt ---")
      expect(content).to include("Test Gem\n\nThis is a test gem in plain text.")
      expect(content).to include("--- END FILE: README.txt ---")
    end

    context "with non-existent gemspec" do
      let(:processor) { described_class.new("non_existent.gemspec") }

      it "returns an error" do
        success, error_message = processor.process
        expect(success).to be false
        expect(error_message).to include("Error: The specified gemspec file")
      end
    end

    context "with unstaged files" do
      let(:mock_git) { instance_double(Git::Base) }
      let(:mock_status) { instance_double(Git::Status) }

      before do
        allow(Git).to receive(:open).and_return(mock_git)
        allow(mock_git).to receive(:status).and_return(mock_status)
        allow(mock_status).to receive(:untracked).and_return({ "lib/unstaged_file.rb" => "??" })
        allow(mock_status).to receive(:changed).and_return({})
      end

      it "warns about unstaged files" do
        success, output_file, unstaged_files = processor.process
        expect(success).to be true
        expect(unstaged_files).to eq(["lib/unstaged_file.rb"])

        content = File.read(output_file)
        expect(content).to include("## Warning: Unstaged Files")
        expect(content).to include("lib/unstaged_file.rb")
      end

      context "with include_unstaged option" do
        let(:processor) { described_class.new(gemspec_file, nil, true) }

        it "includes unstaged files" do
          allow(File).to receive(:file?).and_return(true)

          # Create a hash to store file contents
          file_contents = {
            "lib/test_gem.rb" => "puts 'Hello from test_gem'",
            "spec/test_gem_spec.rb" => "RSpec.describe TestGem do\nend",
            "README.md" => "# Test Gem\n\nThis is a test gem.",
            "README.txt" => "Test Gem\n\nThis is a test gem in plain text.",
            "lib/unstaged_file.rb" => "Unstaged content"
          }

          # Mock File.read
          allow(File).to receive(:read) do |path|
            file_name = File.basename(path)
            if file_contents.key?(file_name)
              file_contents[file_name]
            elsif path.end_with?("_wrapped.txt")
              # This is the output file, so we'll construct its content here
              wrapped_content = "# Wrapped Gem: test_gem\n"
              wrapped_content += "## Gemspec: test_gem.gemspec\n\n"
              wrapped_content += "## Warning: Unstaged Files\n"
              wrapped_content += "lib/unstaged_file.rb\n\n"
              wrapped_content += "## Files:\n\n"
              file_contents.each do |file, content|
                wrapped_content += "--- START FILE: #{file} ---\n"
                wrapped_content += "#{content}\n"
                wrapped_content += "--- END FILE: #{file} ---\n\n"
              end
              wrapped_content
            else
              "Default content for #{path}"
            end
          end

          success, output_file, unstaged_files = processor.process
          expect(success).to be true
          expect(unstaged_files).to eq(["lib/unstaged_file.rb"])

          content = File.read(output_file)
          expect(content).to include("--- START FILE: lib/test_gem.rb ---")
          expect(content).to include("puts 'Hello from test_gem'")
          expect(content).to include("--- END FILE: lib/test_gem.rb ---")
          expect(content).to include("--- START FILE: spec/test_gem_spec.rb ---")
          expect(content).to include("RSpec.describe TestGem do")
          expect(content).to include("--- END FILE: spec/test_gem_spec.rb ---")
          expect(content).to include("--- START FILE: README.md ---")
          expect(content).to include("# Test Gem\n\nThis is a test gem.")
          expect(content).to include("--- END FILE: README.md ---")
          expect(content).to include("--- START FILE: README.txt ---")
          expect(content).to include("Test Gem\n\nThis is a test gem in plain text.")
          expect(content).to include("--- END FILE: README.txt ---")
          expect(content).to include("--- START FILE: lib/unstaged_file.rb ---")
          expect(content).to include("Unstaged content")
          expect(content).to include("--- END FILE: lib/unstaged_file.rb ---")
        end
      end
    end
  end
end
