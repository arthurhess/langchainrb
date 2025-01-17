# frozen_string_literal: true

require "open-uri"

module Langchain
  class Loader
    class FileNotFound < StandardError; end

    class UnknownFormatError < StandardError; end

    URI_REGEX = %r{\A[A-Za-z][A-Za-z0-9+\-.]*://}

    # Load data from a file or URL. Shorthand for  `Langchain::Loader.new(path).load`
    #
    # == Examples
    #
    #     # load a URL
    #     data = Langchain::Loader.load("https://example.com/docs/README.md")
    #
    #     # load a file
    #     data = Langchain::Loader.load("README.md")
    #
    #    # Load data using a custom processor
    #    data = Langchain::Loader.load("README.md") do |raw_data, options|
    #      # your processing code goes here
    #      # return data at the end here
    #    end
    #
    # @param path [String | Pathname] path to file or URL
    # @param options [Hash] options passed to the processor class used to process the data
    # @return [Data] data loaded from path
    def self.load(path, options = {}, &block)
      new(path, options).load(&block)
    end

    # Initialize Langchain::Loader
    # @param path [String | Pathname] path to file or URL
    # @param options [Hash] options passed to the processor class used to process the data
    # @return [Langchain::Loader] loader instance
    def initialize(path, options = {})
      @options = options
      @path = path
    end

    # Is the path a URL?
    #
    # @return [Boolean] true if path is URL
    def url?
      return false if @path.is_a?(Pathname)

      !!(@path =~ URI_REGEX)
    end

    # Load data from a file or URL
    #
    #    loader = Langchain::Loader.new("README.md")
    #    # Load data using default processor for the file
    #    loader.load
    #
    #    # Load data using a custom processor
    #    loader.load do |raw_data, options|
    #      # your processing code goes here
    #      # return data at the end here
    #    end
    #
    # @yield [String, Hash] handle parsing raw output into string directly
    # @yieldparam [String] raw_data from the loaded URL or file
    # @yieldreturn [String] parsed data, as a String
    #
    # @return [Data] data that was loaded
    def load(&block)
      @raw_data = url? ? load_from_url : load_from_path

      data = if block
        yield @raw_data.read, @options
      else
        processor_klass.new(@options).parse(@raw_data)
      end

      Langchain::Data.new(data, source: @path)
    end

    private

    def load_from_url
      URI.parse(@path).open
    end

    def load_from_path
      raise FileNotFound unless File.exist?(@path)

      File.open(@path)
    end

    def processor_klass
      raise UnknownFormatError unless (kind = find_processor)

      Langchain::Processors.const_get(kind)
    end

    def find_processor
      processors.find { |klass| processor_matches? "#{klass}::#{lookup_constant}", source_type }
    end

    def processor_matches?(constant, value)
      Langchain::Processors.const_get(constant).include?(value)
    end

    def processors
      Langchain::Processors.constants
    end

    def source_type
      url? ? @raw_data.content_type : File.extname(@path)
    end

    def lookup_constant
      url? ? :CONTENT_TYPES : :EXTENSIONS
    end
  end
end
