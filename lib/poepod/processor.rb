# frozen_string_literal: true

module Poepod
  # Base class for file processors
  class Processor
    def initialize(config_file = nil)
      @config = load_config(config_file)
    end

    def load_config(config_file)
      if config_file && File.exist?(config_file)
        YAML.load_file(config_file)
      else
        {}
      end
    end

    def process
      raise NotImplementedError, "Subclasses must implement the 'process' method"
    end
  end
end
