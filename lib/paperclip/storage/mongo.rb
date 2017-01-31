module Paperclip
  module Storage
    # GridFS is a specification for storing large files in MongoDB. 
    # You can find out more about it at http://www.mongodb.org/display/DOCS/GridFS
    # When using this module to store your files, it is important to keep in mind that
    # you will need to provide a facility for which to retrieve the stored files.
    # This can be as simple as a route pointing from your upload directory to a 
    # controller that queries MongoDB for the full path it is sent, returning
    # the data with 
    #   send_data @attachment.to_binary, :type => @attachment.content_type, :disposition => 'inline'
    # (or, similarly having selected an object directly from MongoDB as content_type is stored as GridFS metadata)
    # The full binary representation of all of the file's processed styles, as well as
    # the metadata are stored with the path to the file as the unique _id.
    # The Mongo storage module supports a few unique options for has_attached_file:
    # * +mongo_frontend_path+: The path that will be used to retrieve stored files (for example, 'uploads')
    # * +mongo_frontend_host+: The domain that will be used to retrieve stored files (for example, 'somewhere.com')
    # * +mongo_database+: A Mongo::DB object where a GridFS is maintained. This can be omitted only if mongo_grid is specified.
    # * +mongo_grid+: A Mongo::Grid object where the attachments will be stored. This can be omitted only if mongo_database is specified.
    # * +mongo_fs_name+: A name for the GridFS, optional but useful if you wish to keep the attachment GridFS separate from others. 
    # * +url+: There are two options for the generated url. Either an absolute URL to the 
    #   image can be generated (using ":mongo_absolute_url") or a relative URL can be
    #   generated (using ":mongo_relative_url"). 
    # * +path+: This is the key under which the file will be stored (the _id in MongoDB).
    #   URL will be constructed from the frontend parameters and the path. This is what you will want
    #   to interpolate. Keys should be unique, like filenames, and / can still be used as a separator (although
    #   files cannot be requested via a hierarchy).
    # The files stored in MongoDB can be served in a Rails application with a route like:
    #   match '/grid/uploads/:id/:style.:extension', :via => :get, :controller => 'attachments', :action => 'show'
    # And a controller action similar to:
    #   def show
    #     @attachment = Attachment.find(params[:id])
    #     send_file @attachment.data.to_file(params[:style]).path, :type => @attachment.data_content_type, :disposition => 'inline'
    #   end
    # Which would serve an attachment with
    #   :mongo_frontend_path => 'grid', path => 'uploads/:id/:style.:extension', :url => ':mongo_relative_url'
    # Data could also be sent without caching to a temporary file via the to_binary method (and send_data in Rails).
    # This storage module is for some pretty specific use cases and probably shouldn't be used to serve a lot of images
    # loading in a page, since that requires a read from the DB (or at least from the application server) with each call,
    # unless you cache the reads to a directory served directly by your web server.
    module Mongo
      def self.extended base
        begin
          require 'mongo'
        rescue LoadError => e
          e.message << " (You may need to install the mongo gem)"
          raise e
        end

        # Needs MongoDB connection and URL for how the files are served
        # 
        base.instance_eval do 
          @mongo_fs_path = @options[:mongo_frontend_path] || "/" # public facing URL, appended to host
          @mongo_fs_host = @options[:mongo_frontend_host] || "/" # public facing file host
          @mongo_database = @options[:mongo_database] if @options[:mongo_database].present?
          @mongo_fs_name = @options[:mongo_fs_name] || nil
          @mongo_grid = @options[:mongo_grid] if @options[:mongo_grid].present?

          # if a :mongo_*_url is specified, but no path is specified, getting a url will end in an InfiniteInterpolationError
          # same as the S3 module
          unless @url.to_s.match(/^:mongo.*url$/)
            @path          = @path.gsub(/:url/, @url)
            @url           = ":mongo_absolute_url"
          end
          
          if @mongo_grid || @mongo_database then
            if @mongo_grid.nil? then
              @mongo_grid = new_grid(@mongo_database, @mongo_fs_name)
            end
          else
            raise "Either a MongoDB database or a GridFS object must be specified"
          end
        end

        Paperclip.interpolates(:mongo_relative_url) do |attachment, style|
          "/#{attachment.mongo_fs_path}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end
        Paperclip.interpolates(:mongo_absolute_url) do |attachment, style|
          "http://#{attachment.mongo_fs_host}/#{attachment.mongo_fs_path}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end
      end

      attr_reader :mongo_fs_host
      attr_reader :mongo_fs_path

      def new_grid(database, name)
        if(name.nil?) then
          ::Mongo::Grid.new(database)
        else
          ::Mongo::Grid.new(database, name)
        end
      end

      def exists?(style_name = default_style)
        if original_filename
          begin
            @mongo_grid.get(path(style_name))
          rescue ::Mongo::GridFileNotFound => e
            false
          else
            true
          end
        else
          false
        end
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            log("saving #{path(style)}")
            @mongo_grid.put(file, :filename => path(style), :_id => path(style), :content_type => instance_read(:content_type))
          end
        end
        @queued_for_write = {}
      end
      
      # Returns the raw data associated with this attachment
      def to_binary style = default_style
        return @queued_for_write[style].read if @queued_for_write[style]
        @mongo_grid.get(path(style)).read
      end
  
      # Returns the File associated with this attachment.
      def to_file style = default_style
        return @queued_for_write[style] if @queued_for_write[style]
        filename = path(style)
        extname  = File.extname(filename)
        basename = File.basename(filename, extname)
        file = Tempfile.new([basename, extname])
        file.binmode
        file.write(@mongo_grid.get(path(style)).read)
        file.rewind
        return file
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |filename|
          begin
            log("deleting #{filename}")
            @mongo_grid.delete(path(filename))
          end
        end
        @queued_for_delete = []
      end
      
    end
  end
end