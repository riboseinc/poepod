require "spec_helper"
require "poepod/cli"

RSpec.describe Poepod::Cli do
  let(:cli) { described_class.new }

  describe "#concat" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:text_file) { File.join(temp_dir, "text_file.txt") }
    let(:binary_file) { File.join(temp_dir, "binary_file.bin") }

    before do
      File.write(text_file, "Hello, World!")
      File.write(binary_file, [0xFF, 0xD8, 0xFF, 0xE0].pack("C*"))
    end

    after do
      FileUtils.remove_entry(temp_dir)
    end

    it "concatenates text files" do
      output_file = File.join(temp_dir, "output.txt")
      expect { cli.concat(text_file, output_file: output_file) }.to output(/1 files detected/).to_stdout
      expect(File.exist?(output_file)).to be true
      expect(File.read(output_file)).to include("Hello, World!")
    end

    it "excludes binary files by default" do
      output_file = File.join(temp_dir, "output.txt")
      expect { cli.concat(text_file, binary_file, output_file: output_file) }.to output(/-> 2 files detected\.\n=> 1 files have been concatenated into.*\.txt/).to_stdout
    end

    it "includes binary files when specified" do
      output_file = File.join(temp_dir, "output.txt")
      expect { cli.invoke(:concat, [text_file, binary_file], output_file: output_file, include_binary: true) }.to output(/-> 2 files detected\.\n=> 2 files have been concatenated into.*\.txt/).to_stdout
    end
  end

  describe "#wrap" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:gemspec_file) { File.join(temp_dir, "test_gem.gemspec") }

    before do
      File.write(gemspec_file, <<~GEMSPEC)
        Gem::Specification.new do |spec|
          spec.name = "test_gem"
          spec.version = "0.1.0"
          spec.authors = ["Test Author"]
          spec.files = ["lib/test_gem.rb"]
        end
      GEMSPEC

      FileUtils.mkdir_p(File.join(temp_dir, "lib"))
      File.write(File.join(temp_dir, "lib/test_gem.rb"), "puts 'Hello from test_gem'")
    end

    after do
      FileUtils.remove_entry(temp_dir)
    end

    it "wraps a gem" do
      expect { cli.wrap(gemspec_file) }.to output(/The gem has been wrapped into/).to_stdout
      output_file = File.join(Dir.pwd, "test_gem_wrapped.txt")
      expect(File.exist?(output_file)).to be true
      content = File.read(output_file)
      expect(content).to include("# Wrapped Gem: test_gem")
      expect(content).to include("## Gemspec: test_gem.gemspec")
      expect(content).to include("--- START FILE: lib/test_gem.rb ---")
      expect(content).to include("puts 'Hello from test_gem'")
      expect(content).to include("--- END FILE: lib/test_gem.rb ---")
    end

    it "handles non-existent gemspec" do
      expect { cli.wrap("non_existent.gemspec") }.to output(/Error: The specified gemspec file/).to_stdout.and raise_error(SystemExit)
    end
  end
end
