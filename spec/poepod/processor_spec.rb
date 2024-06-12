# frozen_string_literal: true

require "rspec"
require_relative "../../lib/poepod/processor"
require "tempfile"

RSpec.describe Poepod::Processor do
  let(:directory_path) { File.expand_path("#{__dir__}/../support/test_files") }
  let(:output_file_name) { Tempfile.new("output.txt") }
  let(:processor) { described_class.new }

  before do
    File.write("#{directory_path}/file1.txt", "Content of file1.\n")
    File.write("#{directory_path}/file2.txt", "Content of file2.\n")
  end

  after do
    File.delete(output_file_name) if File.exist?(output_file_name)
  end

  describe "#process_file" do
    it "reads the content of a file" do
      file_path = "#{directory_path}/file1.txt"
      _, content, error = processor.process_file(file_path)
      expect(content).to eq("Content of file1.\n")
      expect(error).to be_nil
    end

    it "handles encoding errors gracefully" do
      allow(File).to receive(:read).and_raise(Encoding::InvalidByteSequenceError)
      file_path = "#{directory_path}/file1.txt"
      _, content, error = processor.process_file(file_path)
      expect(content).to be_nil
      expect(error).to eq("Failed to decode the file, as it is not saved with UTF-8 encoding.")
    end
  end

  describe "#gather_files" do
    it "gathers all file paths in a directory" do
      files = processor.gather_files(directory_path, [])
      expect(files).to contain_exactly(
        "#{directory_path}/file1.txt",
        "#{directory_path}/file2.txt"
      )
    end
  end

  describe "#write_results_to_file" do
    it "writes the processed files to the output file" do
      results = [
        ["#{directory_path}/file1.txt", "Content of file1.\n", nil],
        ["#{directory_path}/file2.txt", "Content of file2.\n", nil]
      ]
      File.open(output_file_name, "w", encoding: "utf-8") do |output_file|
        processor.write_results_to_file(results, output_file)
      end
      output_content = File.read(output_file_name, encoding: "utf-8")
      expected_content = <<~TEXT
        --- START FILE: spec/support/test_files/file1.txt ---
        Content of file1.
        --- END FILE: spec/support/test_files/file1.txt ---

        --- START FILE: spec/support/test_files/file2.txt ---
        Content of file2.
        --- END FILE: spec/support/test_files/file2.txt ---
      TEXT
      expect(output_content).to eq(expected_content)
    end
  end

  describe "#write_directory_structure_to_file" do
    it "writes the directory structure to the output file with a progress bar" do
      puts "directory_path: #{directory_path}"
      puts Dir.glob("#{directory_path}/*")
      total_files, copied_files = processor.write_directory_structure_to_file(directory_path, output_file_name)
      expect(total_files).to eq(2)
      expect(copied_files).to eq(2)

      output_content = File.read(output_file_name, encoding: "utf-8")
      expected_content = <<~TEXT
        --- START FILE: spec/support/test_files/file1.txt ---
        Content of file1.
        --- END FILE: spec/support/test_files/file1.txt ---

        --- START FILE: spec/support/test_files/file2.txt ---
        Content of file2.
        --- END FILE: spec/support/test_files/file2.txt ---
      TEXT
      expect(output_content).to eq(expected_content)
    end
  end
end
