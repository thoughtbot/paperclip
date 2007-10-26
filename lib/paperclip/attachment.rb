module Thoughtbot
  module Paperclip
    
    class Attachment
      
      attr_reader :name, :instance, :original_filename, :content_type, :original_file_size, :definition, :errors
      
      def initialize name, active_record
        @instance   = active_record
        @definition = @instance.class.attachment_definitions[name]
        @name       = name
        @errors     = []
        
        self.original_filename = @instance["#{name}_file_name"]
        self.content_type = @instance["#{name}_content_type"]
        self.original_file_size = @instance["#{name}_file_size"]
        @files = {}
        @dirty = false
        
        self.class.send :include, definition.storage_module
      end
      
      def assign uploaded_file
        uploaded_file = fetch_uri(uploaded_file) if uploaded_file.is_a? URI
        return queue_destroy if uploaded_file.nil?
        return unless is_a_file? uploaded_file
        
        self.original_filename = sanitize_filename(uploaded_file.original_filename)
        self.content_type = uploaded_file.content_type
        self.original_file_size = uploaded_file.size
        self[:original] = uploaded_file
        @dirty = true
        
        if definition.type == :image
          make_thumbnails_from uploaded_file
        end
      end
      
      def [](style)
        @files ||= {}
        @files[style]
      end
      alias_method :file_for, :[]
      
      def []=(style, data)
        @files ||= {}
        @files[style] = data
      end
      
      def clear_files
        @files = nil
        @dirty = false
      end
      
      def for_attached_files
        @files.each do |style, data|
          if data
            data.rewind if data.respond_to? :rewind
            yield style, (data.respond_to?(:read) ? data.read : data)
          end
        end
      end
      
      def dirty?
        @dirty
      end
      
      # Validations
      
      def valid?
        definition.validations.each do |validation, constraints|
          send("validate_#{validation}", *constraints)
        end
        errors.empty?
      end
      
      # ActiveRecord Callbacks
      
      def save
        write_attachment  if dirty?
        delete_attachment if @delete_on_save
        @delete_on_save = false
        clear_files
      end

      def queue_destroy(complain = false)
        returning true do
          @delete_on_save        = true
          @complain_on_delete    = complain
          self.original_filename = nil
          self.content_type      = nil
          clear_files
        end
      end

      def destroy
        delete_attachment if definition.delete_on_destroy
      end

      # Image Methods
      
      def make_thumbnails_from data
        begin
          definition.styles.each do |style, geometry|
            self[style] = make_thumbnail geometry, data
          end
        rescue PaperclipError => e
          errors << e.message
          clear_files
          self[:original] = data
        end
      end
            
      def make_thumbnail geometry, data
        return data if geometry.nil?
        
        operator = geometry[-1,1]
        begin
          geometry, crop_geometry = geometry_for_crop(geometry, data) if operator == '#'
          convert = Thoughtbot::Paperclip.path_for_command("convert")
          command = "#{convert} - -scale '#{geometry}' #{operator == '#' ? "-crop '#{crop_geometry}'" : ""} - 2>/dev/null"
          thumb = IO.popen(command, "w+") do |io|
            data.rewind
            io.write(data.read)
            io.close_write
            StringIO.new(io.read)
          end
        rescue Errno::EPIPE => e
          raise PaperclipError.new(self), "could not be thumbnailed. Is ImageMagick or GraphicsMagick installed and available?"
        rescue SystemCallError => e
          raise PaperclipError.new(self), "could not be thumbnailed."
        end
        if Thoughtbot::Paperclip.options[:whiny_thumbnails] && !$?.success?
          raise PaperclipError.new(self), "could not be thumbaniled because of an error with 'convert'."
        end
        thumb
      end
      
      def geometry_for_crop geometry, orig_io
        identify = Thoughtbot::Paperclip.path_for_command("identify")
        IO.popen("#{identify} -", "w+") do |io|
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
      
      # Helper Methods
      
      def interpolate style, source
        returning source.dup do |s|
          s.gsub!(/:rails_root/, RAILS_ROOT)
          s.gsub!(/:id/, instance.id.to_s) if instance.id
          s.gsub!(/:class/, instance.class.to_s.underscore.pluralize)
          s.gsub!(/:style/, style.to_s)
          s.gsub!(/:attachment/, name.to_s.pluralize)
          if original_filename
            file_bits = original_filename.split(".")
            s.gsub!(/:name/, original_filename)
            s.gsub!(/:base/, [file_bits[0], *file_bits[1..-2]].join("."))
            s.gsub!(/:ext/,  file_bits.last )
          end
        end
      end
      
      def original_filename= new_name
        instance["#{name}_file_name"] = @original_filename = new_name
      end
      
      def content_type= new_type
        instance["#{name}_content_type"] = @content_type = new_type
      end
      
      def original_file_size= new_size
        instance["#{name}_file_size"] = @original_file_size = new_size
      end
      
      def fetch_uri uri
        image = if uri.scheme == 'file'
          path = url.gsub(%r{^file://}, '/')
          open(path)
        else
          require 'open-uri'
          uri
        end
        begin
          data = StringIO.new(image.read)
          uri.extend(Upfile)
          class << data
            attr_accessor :original_filename, :content_type
          end
          data.original_filename = uri.original_filename
          data.content_type = uri.content_type
          data
        rescue OpenURI::HTTPError => e
          errors << "The file at #{uri.to_s} could not be found."
          return nil
        end
      end
      
      def is_a_file? data
        [:size, :content_type, :original_filename, :read].map do |meth|
          data.respond_to? meth
        end.all?
      end

      def sanitize_filename filename
        File.basename(filename).gsub(/[^\w\.\_]/,'_')
      end
      protected :sanitize_filename
   
      def to_s
        url
      end
      
    end
  end
end