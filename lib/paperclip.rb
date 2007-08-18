module Thoughtbot
  module Paperclip
    
    DEFAULT_OPTIONS = {
      :path_prefix     => ":rails_root/public/",
      :url_prefix      => "/",
      :path            => ":class/:style/:id",
      :attachment_type => :image,
      :thumbnails      => {}
    }

    module ClassMethods
      def has_attached_file *file_attribute_names
        options = file_attribute_names.last.is_a?(Hash) ? file_attribute_names.pop : {}
        options = DEFAULT_OPTIONS.merge(options)

        include InstanceMethods
        attachments ||= {}

        file_attribute_names.each do |attr|
          attachments[attr] = (attachments[attr] || {:name => attr}).merge(options)

          define_method "#{attr}=" do |uploaded_file|
            return unless is_a_file? uploaded_file
            attachments[attr].merge!({
              :dirty        => true,
              :files        => {:original => uploaded_file},
              :content_type => uploaded_file.content_type,
              :filename     => sanitize_filename(uploaded_file.original_filename)
            })
            write_attribute(:"#{attr}_file_name", attachments[attr][:filename])
            write_attribute(:"#{attr}_content_type", attachments[attr][:content_type])
            
            if attachments[attr][:attachment_type] == :image
              attachments[attr][:thumbnails].each do |style, geometry|
                attachments[attr][:files][style] = make_thumbnail(attachments[attr][:files][:original], geometry)
              end
            end

            uploaded_file
          end
          
          define_method attr do
            self.send("#{attr}_file_name")
          end
          
          define_method "#{attr}_attachment" do
            attachments[attr]
          end
          
          define_method "#{attr}_filename" do |*args|
            style = args.shift || :original # This prevents arity warnings
            self["#{attr}_file_name"] ? path_for(attachments[attr], style) : ""
          end
          
          define_method "#{attr}_url" do |*args|
            style = args.shift || :original # This prevents arity warnings
            self["#{attr}_file_name"] ? url_for(attachments[attr], style) : ""
          end
          
          define_method "#{attr}_valid?" do
            attachments[attr][:thumbnails].all? do |style, geometry|
              attachments[attr][:dirty] ?
                !attachments[attr][:files][style].blank? :
                File.file?( path_for(attachments[attr], style))
            end
          end
          
          define_method "destroy_#{attr}" do
            if attachments[attr].keys.any?
              delete_attachment attachments[attr]
            end
          end

          define_method "#{attr}_after_save" do
            if attachments[attr].keys.any?
              write_attachment attachments[attr] if attachments[attr][:files]
              attachments[attr][:dirty] = false
              attachments[attr][:files] = nil
            end
          end
          private :"#{attr}_after_save"
          after_save :"#{attr}_after_save"
          
          define_method "#{attr}_before_destroy" do
            if attachments[attr].keys.any?
              delete_attachment attachments[attr]
            end
          end
          private :"#{attr}_before_destroy"
          before_destroy :"#{attr}_before_destroy"
        end
      end
    end

    module InstanceMethods
      
      private
      
      def path_for attachment, style = :original
        prefix = File.join(attachment[:path_prefix], attachment[:path])
        prefix.gsub!(/:rails_root/, RAILS_ROOT)
        prefix.gsub!(/:id/, self.id.to_s) if self.id
        prefix.gsub!(/:class/, self.class.to_s.underscore)
        prefix.gsub!(/:style/, style.to_s)
        File.join( prefix.split("/"), read_attribute("#{attachment[:name]}_file_name").to_s )
      end
      
      def url_for attachment, style = :original
        prefix = File.join(attachment[:url_prefix], attachment[:path])
        prefix.gsub!(/:rails_root/, RAILS_ROOT)
        prefix.gsub!(/:id/, self.id.to_s) if self.id
        prefix.gsub!(/:class/, self.class.to_s.underscore)
        prefix.gsub!(/:style/, style.to_s)
        File.join( prefix.split("/"), read_attribute("#{attachment[:name]}_file_name").to_s )
      end
      
      def ensure_directories_for attachment
        attachment[:files].each do |style, file|
          dirname = File.dirname(path_for(attachment, style))
          FileUtils.mkdir_p dirname
        end
      end
      
      def write_attachment attachment
        ensure_directories_for attachment
        attachment[:files].each do |style, atch|
          File.open( path_for(attachment, style), "w" ) do |file|
            atch.rewind
            file.write(atch.read)
          end
        end
      end
      
      def delete_attachment attachment
        (attachment[:thumbnails].keys + [:original]).each do |style|
          file_path = path_for(attachment, style)
          begin
            FileUtils.rm(file_path)
          rescue Errno::ENOENT
            raise if ::Thoughtbot::Paperclip.whiny_deletes?
          end
        end
        self.update_attribute "#{attachment[:name]}_file_name", nil
        self.update_attribute "#{attachment[:name]}_content_type", nil
      end

      def make_thumbnail orig_io, geometry
        thumb = IO.popen("convert - -scale '#{geometry}' -", "w+") do |io|
          orig_io.rewind
          io.write(orig_io.read)
          io.close_write
          io.read
        end
        raise "Convert returned with result code #{$?.exitstatus}." unless $?.success?
        StringIO.new(thumb)
      end
      
      def is_a_file? data
        [:size, :content_type, :original_filename].map do |meth|
          data.respond_to? meth
        end.all?
      end

      def sanitize_filename filename
        File.basename(filename).gsub(/[^\w\.\_]/,'_')
      end
      protected :sanitize_filename
    end
    
    module Upfile
      def content_type
        type = self.path.match(/\.(\w+)$/)[1]
        case type
        when "jpg", "png", "gif" then "image/#{type}"
        when "txt", "csv", "xml", "html", "htm" then "text/#{type}"
        else "application/#{type}"
        end
      end
      
      def original_filename
        self.path
      end
      
      def size
        File.size(self)
      end
    end
    
    def self.whiny_deletes?
      false
    end
  end
end

File.send :include, Thoughtbot::Paperclip::Upfile
