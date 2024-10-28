# frozen_string_literal: true

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
    let(:output_file) { File.join(temp_dir, "test_gem_wrapped.txt") }

    before do
      # Mock Git operations
      allow(Git).to receive(:open).and_return(double(status: double(untracked: {}, changed: {})))
    end

    it "processes the gem files, includes README files, and spec files in sorted order" do
      success, = processor.process(output_file)
      expect(success).to be true
      expect(File.exist?(output_file)).to be true

      content = File.read(output_file)

      file_order = content.scan(/--- START FILE: (.+) ---/).flatten
      expected_order = [
        "README.md",
        "README.txt",
        "lib/test_gem.rb",
        "spec/test_gem_spec.rb"
      ]
      expect(file_order).to eq(expected_order)

      expected = <<~HERE
        --- START FILE: README.md ---
        # Test Gem

        This is a test gem.
        --- END FILE: README.md ---
        --- START FILE: README.txt ---
        Test Gem

        This is a test gem in plain text.
        --- END FILE: README.txt ---
        --- START FILE: lib/test_gem.rb ---
        puts 'Hello from test_gem'
        --- END FILE: lib/test_gem.rb ---
        --- START FILE: spec/test_gem_spec.rb ---
        RSpec.describe TestGem do
        end
        --- END FILE: spec/test_gem_spec.rb ---
      HERE
      expect(content).to eq(expected)
    end

    context "with non-existent gemspec" do
      let(:processor) { described_class.new("non_existent.gemspec") }

      it "returns an error" do
        success, error_message, = processor.process(output_file)
        expect(success).to be false
        expect(error_message).to include("Error: The specified gemspec file")
      end
    end

    context "with unstaged files" do
      let(:processor) { described_class.new(gemspec_file, include_unstaged: false) }
      let(:mock_git) { instance_double(Git::Base) }
      let(:mock_status) { instance_double(Git::Status) }

      before do
        allow(Git).to receive(:open).and_return(mock_git)
        allow(mock_git).to receive(:status).and_return(mock_status)
        allow(mock_status).to receive(:untracked).and_return(
          { "lib/unstaged_file.rb" => "??" }
        )
        allow(mock_status).to receive(:changed).and_return({})
      end

      context "with include_unstaged option" do
        let(:processor) { described_class.new(gemspec_file, include_unstaged: true) }
        let(:output_file) { File.join(temp_dir, "test_gem_wrapped.txt") }

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
              file_contents.map do |file, content|
                <<~HERE
                  --- START FILE: #{file} ---
                  #{content}
                  --- END FILE: #{file} ---
                HERE
              end.join("")
            else
              "Default content for #{path}"
            end
          end

          success, _, unstaged_files = processor.process(output_file)
          expect(success).to be true
          expect(unstaged_files).to eq(["lib/unstaged_file.rb"])

          content = File.read(output_file)
          expected = <<~HERE
            --- START FILE: lib/test_gem.rb ---
            puts 'Hello from test_gem'
            --- END FILE: lib/test_gem.rb ---
            --- START FILE: spec/test_gem_spec.rb ---
            RSpec.describe TestGem do
            end
            --- END FILE: spec/test_gem_spec.rb ---
            --- START FILE: README.md ---
            # Test Gem

            This is a test gem.
            --- END FILE: README.md ---
            --- START FILE: README.txt ---
            Test Gem

            This is a test gem in plain text.
            --- END FILE: README.txt ---
            --- START FILE: lib/unstaged_file.rb ---
            Unstaged content
            --- END FILE: lib/unstaged_file.rb ---
          HERE
          expect(content).to eq(expected)
        end
      end

      context "when gem includes directories in spec.files (e.g., git submodules)" do
        let(:submodule_dir) { File.join(temp_dir, "vendor", "submodule_project") }
        before do
          # Simulate a submodule directory with a file
          FileUtils.mkdir_p(submodule_dir)
          File.write(File.join(submodule_dir, "submodule_file.rb"), "puts 'Hello from submodule'")

          # Update gemspec to include the submodule directory
          File.write(gemspec_file, <<~GEMSPEC)
            Gem::Specification.new do |spec|
              spec.name = "test_gem"
              spec.version = "0.1.0"
              spec.authors = ["Test Author"]
              spec.files = ["lib/test_gem.rb", "vendor/submodule_project"]
              spec.test_files = ["spec/test_gem_spec.rb"]
            end
          GEMSPEC
        end

        it "includes files from directories listed in spec.files" do
          success, = processor.process(output_file)
          expect(success).to be true
          expect(File.exist?(output_file)).to be true

          content = File.read(output_file)
          expect(content).to include("--- START FILE: vendor/submodule_project/submodule_file.rb ---")
          expect(content).to include("puts 'Hello from submodule'")
        end
      end
    end
  end
end
