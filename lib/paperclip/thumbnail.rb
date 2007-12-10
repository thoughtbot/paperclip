module Paperclip
  class Thumbnail
    
    class Geometry
      attr_accessor :height, :width
      def initialize width = nil, height = nil
        @height = (height || width).to_f
        @width = (width || height).to_f
      end
      
      def self.parse string
        if match = (string && string.match(/(\d*)x(\d*)/))
          Geometry.new(*match[1,2])
        end
      end
      
      def square?
        height == width
      end
      
      def horizontal?
        height < width
      end
      
      def vertical?
        height > width
      end
      
      def aspect
        width / height
      end
      
      def larger
        [height, width].max
      end
      
      def smaller
        [height, width].min
      end
      
      def to_s
        "#{width}x#{height}"
      end
      
      def inspect
        to_s
      end
    end
    
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
        if src = Geometry.parse(dimensions)
          dst = Geometry.parse(geometry)
          
          ratio = Geometry.new( dst.width / src.width, dst.height / src.height )
          scale_geometry, scale = if ratio.horizontal? || ratio.square?
            [ "%dx" % dst.width, ratio.width ]
          else
            [ "x%d" % dst.height, ratio.height ]
          end
          
          crop_geometry = if ratio.horizontal? || ratio.square?
            "%dx%d+%d+%d" % [ dst.width, dst.height, 0, (src.height * scale - dst.height) / 2 ]
          else
            "%dx%d+%d+%d" % [ dst.width, dst.height, (src.width * scale - dst.width) / 2, 0 ]
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