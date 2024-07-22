# frozen_string_literal: true

# spec/poepod/file_processor_spec.rb
require "spec_helper"
require "poepod/file_processor"
require "tempfile"

RSpec.describe Poepod::FileProcessor do
  let(:temp_dir) { Dir.mktmpdir }
  let(:output_file) { Tempfile.new("output.txt") }
  let(:text_file1) { File.join(temp_dir, "file1.txt") }
  let(:text_file2) { File.join(temp_dir, "file2.txt") }
  let(:binary_file) { File.join(temp_dir, "binary_file.bin") }

  before do
    File.write(text_file1, "Content of file1.\n")
    File.write(text_file2, "Content of file2.\n")
    File.write(binary_file, [0xFF, 0xD8, 0xFF, 0xE0].pack("C*"))
  end

  after do
    FileUtils.remove_entry(temp_dir)
    output_file.unlink
  end

  let(:processor) { described_class.new([text_file1, text_file2], output_file.path) }

  describe "#process" do
    it "processes text files and writes them to the output file" do
      total_files, copied_files = processor.process
      expect(total_files).to eq(2)
      expect(copied_files).to eq(2)

      output_content = File.read(output_file.path, encoding: "utf-8")
      expected_content = <<~TEXT
        --- START FILE: #{text_file1} ---
        Content of file1.
        --- END FILE: #{text_file1} ---
        --- START FILE: #{text_file2} ---
        Content of file2.
        --- END FILE: #{text_file2} ---
      TEXT
      expect(output_content).to eq(expected_content)
    end
  end

  describe "#process_file" do
    it "reads the content of a file" do
      file_path, content, error = processor.send(:process_file, text_file1)
      expect(file_path).to eq(text_file1)
      expect(content).to eq("Content of file1.\n")
      expect(error).to be_nil
    end

    it "handles encoding errors gracefully" do
      allow(File).to receive(:read).and_raise(Encoding::InvalidByteSequenceError)
      file_path, content, error = processor.send(:process_file, text_file1)
      expect(file_path).to eq(text_file1)
      expect(content).to be_nil
      expect(error).to eq("Failed to decode the file, as it is not saved with UTF-8 encoding.")
    end
  end
end
