module Thoughtbot
  module Paperclip
    class Storage
      def interpolate attachment, source, style 
        style ||= attachment[:default_style]
        file_name = attachment[:instance]["#{attachment[:name]}_file_name"]
        returning source.dup do |s|
          s.gsub!(/:rails_root/, RAILS_ROOT)
          s.gsub!(/:id/, attachment[:instance].id.to_s) if attachment[:instance].id
          s.gsub!(/:class/, attachment[:instance].class.to_s.underscore.pluralize)
          s.gsub!(/:style/, style.to_s )
          s.gsub!(/:attachment/, attachment[:name].to_s.pluralize)
          if file_name
            file_bits = file_name.split(".")
            s.gsub!(/:name/, file_name)
            s.gsub!(/:base/, [file_bits[0], *file_bits[1..-2]].join("."))
            s.gsub!(/:ext/,  file_bits.last )
          end
        end
      end

      def make_thumbnails attachment
        attachment[:files] ||= {}
        attachment[:files][:original] ||= File.new( path_for(attachment, :original) )
        attachment[:thumbnails].each do |style, geometry|
          begin
            attachment[:files][style] = make_thumbnail(attachment, attachment[:files][:original], geometry)
          rescue PaperclipError => e
            attachment[:errors] << "thumbnail '#{style}' could not be created."
          end
        end
      end

      def make_thumbnail attachment, orig_io, geometry
        operator = geometry[-1,1]
        begin
          geometry, crop_geometry = geometry_for_crop(geometry, orig_io) if operator == '#'
          command = "#{path_for_command "convert"} - -scale '#{geometry}' #{operator == '#' ? "-crop '#{crop_geometry}'" : ""} - 2>/dev/null"
          thumb = IO.popen(command, "w+") do |io|
            orig_io.rewind
            io.write(orig_io.read)
            io.close_write
            StringIO.new(io.read)
          end
        rescue Errno::EPIPE => e
          raise PaperclipError.new(attachment), "Could not create thumbnail. Is ImageMagick or GraphicsMagick installed and available?"
        rescue SystemCallError => e
          raise PaperclipError.new(attachment), "Could not create thumbnail."
        end
        if ::Thoughtbot::Paperclip.options[:whiny_thumbnails] && !$?.success?
          raise PaperclipError.new(attachment), "Convert returned with result code #{$?.exitstatus}: #{thumb.read}"
        end
        thumb
      end

      def geometry_for_crop geometry, orig_io
        IO.popen("#{path_for_command "identify"} - 2>/dev/null", "w+") do |io|
          orig_io.rewind
          io.write(orig_io.read)
          io.close_write
          if match = io.read.split[2].match(/(\d+)x(\d+)/)
            src   = match[1,2].map(&:to_f)
            srch  = src[0] > src[1] 
            dst   = geometry.match(/(\d+)x(\d+)/)[1,2].map(&:to_f)
            dsth  = dst[0] > dst[1]
            ar    = src[0] / src[1]

            scale_geometry, scale = if dst[0] == dst[1]
              if srch
                [ "x#{dst[1]}", src[1] / dst[1] ]
              else
                [ "#{dst[0]}x", src[0] / dst[0] ]
              end
            elsif dsth
              [ "#{dst[0]}x", src[0] / dst[0] ]
            else
              [ "x#{dst[1]}", src[1] / dst[1] ]
            end

            crop_geometry = if dsth
              "%dx%d+%d+%d" % [ dst[0], dst[1], 0, (src[1] / scale - dst[1]) / 2 ]
            else
              "%dx%d+%d+%d" % [ dst[0], dst[1], (src[0] / scale - dst[0]) / 2, 0 ]
            end

            [ scale_geometry, crop_geometry ]
          end
        end
      end

      def path_for_command command
        File.join([::Thoughtbot::Paperclip.options[:image_magick_path], command].compact)
      end

      def to_s
        self.class.name
      end
    end
  end
end