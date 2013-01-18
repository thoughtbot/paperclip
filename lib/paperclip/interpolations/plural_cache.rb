module Paperclip
  module Interpolations
    class PluralCache
      def initialize
        @cache = {}
      end

      def pluralize(word)
        @cache[word] ||= word.pluralize
      end

      def underscore_and_pluralize(word)
        @cache[word] ||= word.underscore.pluralize
      end
    end
  end
end
