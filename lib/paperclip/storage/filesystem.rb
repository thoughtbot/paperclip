module Thoughtbot
  module Paperclip
    
    module ClassMethods
      def has_attached_file_with_filesystem *attachment_names
        has_attached_file_without_filesystem *attachment_names
      end
      alias_method_chain :has_attached_file, :filesystem
    end

    class Storage #:nodoc:
      class Filesystem < Storage #:nodoc:
        def path_for attachment, style = nil
          style ||= attachment[:default_style]
          file = attachment[:instance]["#{attachment[:name]}_file_name"]
          return nil unless file && attachment[:instance].id

          prefix = interpolate attachment, "#{attachment[:path_prefix]}/#{attachment[:path]}", style
          File.join( prefix.split("/") )
        end

        def url_for attachment, style = nil
          style ||= attachment[:default_style]
          file = attachment[:instance]["#{attachment[:name]}_file_name"]
          return nil unless file && attachment[:instance].id

          interpolate attachment, "#{attachment[:url_prefix]}/#{attachment[:path]}", style
        end

        def ensure_directories_for attachment
          attachment[:files].each do |style, file|
            dirname = File.dirname(path_for(attachment, style))
            FileUtils.mkdir_p dirname
          end
        end

        def write_attachment attachment
          return if attachment[:files].blank?
          ensure_directories_for attachment
          attachment[:files].each do |style, atch|
            atch.rewind
            data = atch.read
            File.open( path_for(attachment, style), "w" ) do |file|
              file.rewind
              file.write(data)
            end
          end
          attachment[:files] = nil
          attachment[:dirty] = false
        end

        def delete_attachment attachment, complain = false
          (attachment[:thumbnails].keys + [:original]).each do |style|
            file_path = path_for(attachment, style)
            begin
              FileUtils.rm file_path if file_path
            rescue SystemCallError => e
              raise PaperclipError.new(attachment), "Could not delete thumbnail." if ::Thoughtbot::Paperclip.options[:whiny_deletes] || complain
            end
          end
        end

        def attachment_valid? attachment
          attachment[:thumbnails].merge(:original => nil).all? do |style, geometry|
            if attachment[:instance]["#{attachment[:name]}_file_name"]
              if attachment[:dirty]
                !attachment[:files][style].blank? && attachment[:errors].empty?
              else
                File.file?( path_for(attachment, style) )
              end
            else
              false
            end
          end
        end
      end
    end
  end
end