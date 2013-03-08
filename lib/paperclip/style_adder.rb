require 'paperclip/style_migration'
require 'paperclip/style_adder'

module Paperclip
  class StyleAdder < StyleMigration
    def run(styles)
      each_attachment do |attachment|
        file = Paperclip.io_adapters.for(attachment)
        attachment.instance_variable_set('@queued_for_write', {:original => file})

        attachment.send(:post_process, *styles_for(attachment, styles))

        attachment.save
      end
    end

    private

    def styles_for(attachment, styles)
      expected_styles = attachment.send(:styles).keys
      if subset?(styles.keys, expected_styles)
        styles.keys
      else
        raise ArgumentError, "unsupported styles; excepted any of #{expected_styles}"
      end
    end

    def subset?(smaller, larger)
      (smaller - larger).empty?
    end
  end
end
