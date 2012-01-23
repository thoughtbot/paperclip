module Paperclip
  module Validations
    class AttachmentSizeValidator < ActiveModel::EachValidator
      CHECKS = {:greater_than => :>=, :less_than => :<=}.freeze
      RESERVED_OPTIONS = [:greater_than, :less_than, :in, :within].freeze

      def initialize(options)
        if range = options.delete(:in) || options.delete(:within)
          unless range.is_a?(Range)
            raise ArgumentError, ":in and :within must be a Range"
          end

          options[:greater_than], options[:less_than] = range.min, range.max
        end

        options[:greater_than] ||= 0
        options[:less_than]    ||= 1024**3 # 1 GB

        super
      end

      private

      def validate_each(record, attribute, value)
        return if value.nil?

        CHECKS.each do |key, validity_check|
          next unless check_value = options[key]
          next if value.send(validity_check, check_value)

          error_options = options.except(*RESERVED_OPTIONS)
          record.errors.add(attribute, error_message, error_options)

          break
        end
      end

      def check_validity!
        keys = CHECKS.keys & options.keys

        if keys.empty?
          raise ArgumentError, "Range unspecified. Specify the :in, :within, :greated_than or :less_than option."
        end

        keys.each do |key|
          value = options[key]

          unless value.is_a?(Integer) && value >= 0
            raise ArgumentError, ":#{key} must be a nonnegative Integer"
          end
        end
      end

      def error_message
        min, max = options[:greater_than], options[:less_than]

        message = options[:message]
        message = message.call if message.respond_to?(:call)
        message ||= I18n.translate(:size,
          :scope => [:paperclip, :errors],
          :min => min,
          :max => max,
          :default => "file size must be between #{min} and #{max} bytes"
        )
        message.gsub(/:min/, min.to_s).gsub(/:max/, max.to_s)
      end
    end

    module HelperMethods
      # Places ActiveRecord-style validations on the size of the file assigned. The
      # possible options are:
      # * +in+: a Range of bytes (i.e. +1..1.megabyte+),
      # * +less_than+: equivalent to :in => 0..options[:less_than]
      # * +greater_than+: equivalent to :in => options[:greater_than]..Infinity
      # * +message+: error message to display, use :min and :max as replacements
      # * +if+: A lambda or name of an instance method. Validation will only
      #   be run if this lambda or method returns true.
      # * +unless+: Same as +if+ but validates if lambda or method returns false.
      def validates_attachment_size(*attr_names)
        options = attr_names.extract_options!
        attr_names = attr_names.map {|name| "#{name}_file_size"}
        options = options.merge(:attributes => attr_names)

        validates_with AttachmentSizeValidator, options
      end
    end
  end
end
