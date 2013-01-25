require 'singleton'

module Paperclip
  module Tasks
    class Attachments
      include Singleton

      def self.add(klass, attachment_name, attachment_options)
        instance.add(klass, attachment_name, attachment_options)
      end

      def self.names_for(klass)
        instance.names_for(klass)
      end

      def self.definitions_for(klass)
        instance.definitions_for(klass)
      end

      def add(klass, attachment_name, attachment_options)
        @attachments ||= {}
        @attachments[klass] ||= {}
        @attachments[klass][attachment_name] = attachment_options
      end

      def names_for(klass)
        @attachments[klass].keys
      end

      def definitions_for(klass)
        @attachments[klass]
      end
    end
  end
end
