module Paperclip
  module Storage
    module Filesystem
      def write_attachment
        ensure_directories
        for_attached_files do |style, data|
          File.open( file_name(style), "w" ) do |file|
            file.rewind
            file.write(data) if data
          end
        end
      end

      def read_attachment style = nil
        IO.read(file_name(style))
      end

      def delete_attachment complain = false
        for_attached_files do |style, data|
          file_path = file_name(style)
          begin
            FileUtils.rm file_path if file_path
          rescue SystemCallError => e
            raise PaperclipError, "could not be deleted." if Paperclip.options[:whiny_deletes] || complain
          end
        end
      end
      
      def attachment_exists? style = nil
        File.exists?( file_name(style) )
      end

      def file_name style = nil
        style ||= definition.default_style
        interpolate( style, definition.path )
      end

      def ensure_directories
        for_attached_files do |style, file|
          dirname = File.dirname( file_name(style) )
          FileUtils.mkdir_p dirname
        end
      end
    end
  end
end