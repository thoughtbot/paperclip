module Paperclip
  class AttachmentAdapter < AbstractAdapter
    @@_tempfile_cache = {}

    def self.register
      Paperclip.io_adapters.register self do |target|
        Paperclip::Attachment === target || Paperclip::Style === target
      end
    end

    def initialize(target, options = {})
      super
      @target, @style = case target
      when Paperclip::Attachment
        [target, :original]
      when Paperclip::Style
        [target.attachment, target.name]
      end

      cache_current_values
    end

    private

    def cache_current_values
      self.original_filename = @target.original_filename
      @content_type = @target.content_type
      @tempfile = copy_to_tempfile(@target)
      @size = @tempfile.size || @target.size
    end

    ### Mike, you added this and the insanity in copy_to_tempfile, plus the getter in AbstractAdapter
    def tempfile
      if @tempfile.nil? || @tempfile.path.nil? || !File.exist?(@tempfile.path)
        @tempfile = copy_to_tempfile(@target)
      end

      @tempfile
    end

    def copy_to_tempfile(source)
      if @@_tempfile_cache[source].nil? || @@_tempfile_cache[source].path.nil? || !File.exist?(@@_tempfile_cache[source].path)
        @@_tempfile_cache[source] = uncached_copy_to_tempfile(source)
      end

      @@_tempfile_cache[source]
    end

    def uncached_copy_to_tempfile(source)
      p "AttachmentAdapter#uncached_copy_to_tempfile(#{source})"
      if source.staged?
        link_or_copy_file(source.staged_path(@style), destination.path)
      else
        begin
          source.copy_to_local_file(@style, destination.path)
        rescue Errno::EACCES => e
          # clean up lingering tempfile if we cannot access source file
          destination.close(true)
          raise
        end
      end

      destination
    end
  end
end

Paperclip::AttachmentAdapter.register
