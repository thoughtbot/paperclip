module Paperclip
  class Processor
    attr_accessor :file, :options

    def initialize file, options = {}
      @file = file
      @options = options
    end

    def make
    end

    def self.make file, options = {}
      new(file, options).make
    end
  end
end
