module Paperclip
  module Storage
    module DelayedFog
      
      def self.extended base
        
        # Cache the current_url before Fog changes it
        current_url = base.instance_eval{@url}
        
        base.extend Fog
        
        # Set the processing property to true whenever we update the file.
        # It's important to add it to the eigenclass, not the actual Attachment class,
        # else there will be conflicts if using multiple storage methods in one application.
        class << base
          alias_method :original_assign, :assign
          define_method :assign do |uploaded_file|
            file = original_assign(uploaded_file)
            instance_write(:processing, true) if @dirty
            file
          end
        end

        base.instance_eval do
          @url = current_url if on_filesystem?
        end
      end
        
      # Include both Fog and Filesystem, renaming the methods as we go
      # We can then refer to either fog or filesystem depending on where the photo is living.
      include Fog
      alias_method :fog_exists?, :exists?
      alias_method :fog_flush_writes, :flush_writes
      alias_method :fog_flush_deletes, :flush_deletes
      alias_method :fog_to_file, :to_file
        
      include Filesystem
      alias_method :filesystem_exists?, :exists?
      alias_method :filesystem_public_url, :public_url
      alias_method :filesystem_flush_writes, :flush_writes
      alias_method :filesystem_flush_deletes, :flush_deletes
      alias_method :filesystem_to_file, :to_file
      
      def exists?(style = default_style)
        on_filesystem?? filesystem_exists?(style) : fog_exists?()
      end
      
      def upload
        @queued_for_write = {default_style => path(default_style)}
        styles.each{|style| @queued_for_write[style] = path(style)}
        fog_flush_writes
        instance_write(:processing, false)
        instance.save!
        @on_filesystem = false
        @url = ':fog_public_url'
      end
      
      def flush_deletes
        on_filesystem?? filesystem_flush_deletes : fog_flush_deletes
      end
      
      def to_file
        on_filesystem?? filesystem_to_file : fog_to_file
      end
      
      private
      
      # Anything other than true should return false
      def on_filesystem?
        return @on_filesystem unless @on_filesystem === nil
        !( instance_read(:processing) === false )
      end
    end
  end
end