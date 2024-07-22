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
  let(:dot_file) { File.join(temp_dir, ".hidden_file") }

  before do
    File.write(text_file1, "Content of file1.\n")
    File.write(text_file2, "Content of file2.\n")
    File.write(binary_file, [0xFF, 0xD8, 0xFF, 0xE0].pack("C*"))
    File.write(dot_file, "Content of hidden file.\n")
  end

  after do
    FileUtils.remove_entry(temp_dir)
    output_file.unlink
  end

  describe "#process" do
    context "with default options" do
      let(:processor) { described_class.new([File.join(temp_dir, "*")], output_file.path) }

      it "processes text files and excludes binary and dot files" do
        total_files, copied_files = processor.process
        expect(total_files).to eq(3) # Only text files
        expect(copied_files).to eq(2) # Only text files

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

    context "with include_binary option" do
      let(:processor) { described_class.new([File.join(temp_dir, "*")], output_file.path, nil, true) }

      it "includes binary files" do
        total_files, copied_files = processor.process
        expect(total_files).to eq(3) # Text files and binary file
        expect(copied_files).to eq(3) # Text files and binary file

        output_content = File.read(output_file.path, encoding: "utf-8")
        expected_content = <<~TEXT
          --- START FILE: #{binary_file} ---
          Content-Type: application/octet-stream
          Content-Transfer-Encoding: base64

          /9j/4A==
          --- END FILE: #{binary_file} ---
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

    context "with include_dot_files option" do
      let(:processor) { described_class.new([File.join(temp_dir, "*")], output_file.path, nil, false, true) }

      it "includes dot files" do
        total_files, copied_files = processor.process
        expect(total_files).to eq(4) # Text files and dot file
        expect(copied_files).to eq(3) # Text files and dot file

        output_content = File.read(output_file.path, encoding: "utf-8")
        expected_content = <<~TEXT
          --- START FILE: #{dot_file} ---
          Content of hidden file.
          --- END FILE: #{dot_file} ---
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

    context "with both include_binary and include_dot_files options" do
      let(:processor) { described_class.new([File.join(temp_dir, "*")], output_file.path, nil, true, true) }

      it "includes all files in sorted order" do
        total_files, copied_files = processor.process
        expect(total_files).to eq(4) # All files
        expect(copied_files).to eq(4) # All files

        output_content = File.read(output_file.path, encoding: "utf-8")
        expected_content = [
          "--- START FILE: #{dot_file} ---",
          "Content of hidden file.",
          "--- END FILE: #{dot_file} ---",
          "--- START FILE: #{binary_file} ---",
          "Content-Type: application/octet-stream",
          "Content-Transfer-Encoding: base64",
          "",
          "/9j/4A==",
          "--- END FILE: #{binary_file} ---",
          "--- START FILE: #{text_file1} ---",
          "Content of file1.",
          "--- END FILE: #{text_file1} ---",
          "--- START FILE: #{text_file2} ---",
          "Content of file2.",
          "--- END FILE: #{text_file2} ---"
        ].join("\n") + "\n"

        expect(output_content).to eq(expected_content)
      end
    end
  end

  describe "#process_file" do
    let(:processor) { described_class.new([text_file1], output_file.path) }

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
