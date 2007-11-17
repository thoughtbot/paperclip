module Paperclip
  class Thumbnail
    
    attr_accessor :geometry, :data
    
    def initialize geometry, data
      @geometry, @data = geometry, data
    end

    def self.make geometry, data
      new(geometry, data).make
    end

    def make
      return data if geometry.nil?
      operator = geometry[-1,1]
      begin
        scale_geometry = geometry
        scale_geometry, crop_geometry = geometry_for_crop if operator == '#'
        convert = Paperclip.path_for_command("convert")
        command = "#{convert} - -scale '#{scale_geometry}' #{operator == '#' ? "-crop '#{crop_geometry}'" : ""} - 2>/dev/null"
        thumb = piping data, :to => command
      rescue Errno::EPIPE => e
        raise PaperclipError, "could not be thumbnailed. Is ImageMagick or GraphicsMagick installed and available?"
      rescue SystemCallError => e
        raise PaperclipError, "could not be thumbnailed."
      end
      if Paperclip.options[:whiny_thumbnails] && !$?.success?
        raise PaperclipError, "could not be thumbnailed because of an error with 'convert'."
      end
      thumb
    end

    def geometry_for_crop
      identify = Paperclip.path_for_command("identify")
      piping data, :to => "#{identify} - 2>/dev/null" do |pipeout|
        dimensions = pipeout.split[2]
        if dimensions && (match = dimensions.match(/(\d+)x(\d+)/))
          src   = match[1,2].map(&:to_f)
          srch  = src[0] > src[1]
          dst   = geometry.match(/(\d+)x(\d+)/)[1,2].map(&:to_f)
          dsth  = dst[0] > dst[1]
          ar    = src[0] / src[1]

          scale_geometry, scale = if dst[0] == dst[1]
            if srch
              [ "x#{dst[1].to_i}", src[1] / dst[1] ]
            else
              [ "#{dst[0].to_i}x", src[0] / dst[0] ]
            end
          elsif dsth
            [ "#{dst[0].to_i}x", src[0] / dst[0] ]
          else
            [ "x#{dst[1].to_i}", src[1] / dst[1] ]
          end

          crop_geometry = if dsth
            "%dx%d+%d+%d" % [ dst[0], dst[1], 0, (src[1] / scale - dst[1]) / 2 ]
          else
            "%dx%d+%d+%d" % [ dst[0], dst[1], (src[0] / scale - dst[0]) / 2, 0 ]
          end

          [ scale_geometry, crop_geometry ]
        else
          raise PaperclipError, "does not contain a valid image."
        end
      end
    end

    def piping data, command, &block
      self.class.piping(data, command, &block)
    end

    def self.piping data, command, &block
      command = command[:to] if command.respond_to?(:[]) && command[:to]
      block ||= lambda {|d| d }
      IO.popen(command, "w+") do |io|
        io.write(data)
        io.close_write
        block.call(io.read)
      end
    end
  end
end