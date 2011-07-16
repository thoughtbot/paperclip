module Paperclip
  module Storage
    module DelayedFog
      
      def self.extended base
        base.extend Fog
        class << base
          alias_method :original_assign, :assign
          define_method :assign do |uploaded_file|
            file = original_assign(uploaded_file)
            instance_write(:processing, true) if @dirty
            file
          end
        end

        @url = ':delayed_fog_public_url'
        Paperclip.interpolates(:delayed_fog_public_url) do |attachment, style|
          attachment.url(style)
        end unless Paperclip::Interpolations.respond_to? :delayed_fog_public_url
      end
        
      # Include both Fog and Filesystem, renaming the methods as we go
      # We can then refer to either fog or filesystem depending on where the photo is living.
      include Fog
      alias_method :fog_exists?, :exists?
      alias_method :fog_flush_writes, :flush_writes
      alias_method :fog_flush_deletes, :flush_deletes
      alias_method :fog_to_file, :to_file
      alias_method :fog_public_url, :public_url
        
      include Filesystem
      alias_method :filesystem_exists?, :exists?
      alias_method :filesystem_public_url, :public_url
      alias_method :filesystem_flush_writes, :flush_writes
      alias_method :filesystem_flush_deletes, :flush_deletes
      alias_method :filesystem_to_file, :to_file
      
      def on_filesystem?
        instance_read(:processing)
      end
      
      def exists?(style = default_style)
        on_filesystem?? filesystem_exists?(style) : fog_exists?()
      end
      
      def url(style = default_style)
        on_filesystem?? super(style) : fog_public_url(style)
      end
      
      def upload
        @queued_for_write = {default_style => path(default_style)}
        styles.each{|style| @queued_for_write[style] = path(style)}
        fog_flush_writes
        instance_write(:processing, false)
        instance.save!
      end
      
      def flush_deletes
        on_filesystem?? filesystem_flush_deletes : fog_flush_deletes
      end
      
      def to_file
        on_filesystem?? filesystem_to_file : fog_to_file
      end
    end
  end
end