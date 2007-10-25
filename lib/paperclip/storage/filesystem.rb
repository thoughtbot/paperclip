module Thoughtbot
  module Paperclip
    module Storage
      # == Filesystem
      # Typically, Paperclip stores your files in the filesystem, so that Apache (or whatever your
      # main asset server is) can easily access your files without Rails having to be called all
      # the time.
      module Filesystem

        def file_name style = nil
          style ||= @definition.default_style
          pattern = if original_filename && instance.id
            File.join(@definition.path_prefix, @definition.path)
          else
            @definition.missing_file_name
          end
          interpolate( style, pattern )
        end

        def url style = nil
          style ||= @definition.default_style
          pattern = if original_filename && instance.id
            [@definition.url_prefix, @definition.url || @definition.path].compact.join("/")
          else
            @definition.missing_url
          end
          interpolate( style, pattern )
        end

        def write_attachment
          return if @files.blank?
          ensure_directories
          @files.each do |style, data|
            data.rewind
            data = data.read
            File.open( file_name(style), "w" ) do |file|
              file.rewind
              file.write(data)
            end
          end
        end

        def delete_attachment complain = false
          @definition.styles.keys.each do |style|
            file_path = file_name(style)
            begin
              FileUtils.rm file_path if file_path
            rescue SystemCallError => e
              raise PaperclipError.new(self), "Could not delete thumbnail." if Thoughtbot::Paperclip.options[:whiny_deletes] || complain
            end
          end
        end
        
        def validate_existence *constraints
          @definition.styles.keys.each do |style|
            if @dirty
              errors << "requires a valid #{style} file." unless @files && @files[style]
            else
              errors << "requires a valid #{style} file." unless File.exists?( file_name(style) )
            end
          end
        end
        
        def validate_size *constraints
          errors << "file too large. Must be under #{constraints.last} bytes." if original_file_size > constraints.last
          errors << "file too small. Must be over #{constraints.first} bytes." if original_file_size <= constraints.first
        end
        
        private

        def ensure_directories
          @files.each do |style, file|
            dirname = File.dirname( file_name(style) )
            FileUtils.mkdir_p dirname
          end
        end

      end
    end
  end
end