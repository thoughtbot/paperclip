module Paperclip
  module Storage

    module Fog
      def self.extended base
        begin
          require 'fog'
        rescue LoadError => e
          e.message << " (You may need to install the fog gem)"
          raise e
        end unless defined?(Fog)

        base.instance_eval do
          @fog_directory    = @options[:fog_directory]
          @fog_credentials  = @options[:fog_credentials]
          @fog_host         = @options[:fog_host]
          @fog_public       = @options[:fog_public]
          @fog_file         = @options[:fog_file] || {}

          @url = ':fog_public_url'
          Paperclip.interpolates(:fog_public_url) do |attachment, style|
            attachment.public_url(style)
          end unless Paperclip::Interpolations.respond_to? :fog_public_url
        end
      end

      def exists?(style = default_style)
        if original_filename
          !!directory.files.head(path(style))
        else
          false
        end
      end

      def flush_writes
        for style, file in @queued_for_write do
          log("saving #{path(style)}")
          retried = false
          begin
            directory.files.create(@fog_file.merge(
              :body   => file,
              :key    => path(style),
              :public => @fog_public
            ))
          rescue Excon::Errors::NotFound
            raise if retried
            retried = true
            directory.save
            retry
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes
        for path in @queued_for_delete do
          log("deleting #{path}")
          directory.files.new(:key => path).destroy
        end
        @queued_for_delete = []
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file(style = default_style)
        if @queued_for_write[style]
          @queued_for_write[style]
        else
          body      = directory.files.get(path(style)).body
          filename  = path(style)
          extname   = File.extname(filename)
          basename  = File.basename(filename, extname)
          file      = Tempfile.new([basename, extname])
          file.binmode
          file.write(body)
          file.rewind
          file
        end
      end

      def public_url(style = default_style)
        if @fog_host
          "#{@fog_host}/#{path(style)}"
        else
          directory.files.new(:key => path(style)).public_url
        end
      end

      private

      def connection
        @connection ||= ::Fog::Storage.new(@fog_credentials)
      end

      def directory
        @directory ||= connection.directories.new(:key => @fog_directory)
      end

    end

  end
end
