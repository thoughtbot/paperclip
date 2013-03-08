require 'paperclip/style_migration'
require 'paperclip/style_remover'

module Paperclip
  class StyleRemover < StyleMigration
    def run(style_name)
      each_attachment do |attachment|
        attachment.clear(style_name)
        attachment.save
      end
    end
  end
end
