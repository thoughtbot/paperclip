module Paperclip

  # == Attachment
  # Handles all the file management for the attachment, including saving, loading, presenting URLs,
  # and database storage.
  class Attachment

    attr_reader :name, :instance, :original_filename, :content_type, :original_file_size, :definition, :errors

    def initialize active_record, name, definition
      @instance   = active_record
      @definition = definition
      @name       = name
      @errors     = []

      clear_files
      @dirty = true

      self.original_filename  = @instance["#{name}_file_name"]
      self.content_type       = @instance["#{name}_content_type"]
      self.original_file_size = @instance["#{name}_file_size"]
      
      storage_module = Paperclip::Storage.const_get((definition.storage || :filesystem).to_s.camelize)
      self.extend(storage_module)
    end

    def assign uploaded_file
      return destroy if uploaded_file.nil?
      return unless is_a_file? uploaded_file

      self.original_filename  = sanitize_filename(uploaded_file.original_filename)
      self.content_type       = uploaded_file.content_type
      self.original_file_size = uploaded_file.size
      self[:original]         = uploaded_file.read
      @dirty                  = true

      if definition.attachment_type == :image
        make_thumbnails_from(self[:original])
      end
    end

    def [](style)
      @files[style]
    end

    def []=(style, data)
      @files[style] = data
    end

    def clear_files
      @files = {}
      definition.styles.each{|style, geo| self[style] = nil }
      @dirty = false
    end

    def for_attached_files
      @files.each do |style, data|
        yield style, data
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
      errors.uniq!.empty?
    end

    # ActiveRecord Callbacks

    def save
      write_attachment  if dirty?
      delete_attachment if @delete_on_save
      @delete_on_save = false
      clear_files
    end

    def destroy(complain = false)
      returning true do
        @delete_on_save         = true
        @complain_on_delete     = complain
        self.original_filename  = nil
        self.content_type       = nil
        self.original_file_size = nil
        clear_files
      end
    end

    def destroy!
      delete_attachment if definition.delete_on_destroy
    end

    def url style = nil
      style ||= definition.default_style
      pattern = if original_filename && instance.id
        definition.url
      else
        definition.missing_url
      end
      interpolate( style, pattern )
    end

    def read style = nil
      style ||= definition.default_style
      self[style] ? self[style] : read_attachment(style)  
    end

    def validate_existence *constraints
      definition.styles.keys.each do |style|
        errors << "requires a valid #{style} file." unless attachment_exists?(style)
      end
    end

    def validate_size *constraints
      errors << "file too large. Must be under #{constraints.last} bytes." if original_file_size > constraints.last
      errors << "file too small. Must be over #{constraints.first} bytes." if original_file_size <= constraints.first
    end

    def exists?(style)
      style ||= definition.default_style
      attachment_exists?(style)
    end

    def make_thumbnails_from data
      begin
        definition.thumbnails.each do |style, geometry|
          self[style] = Thumbnail.make(geometry, data)
        end
      rescue PaperclipError => e
        errors << e.message
        clear_files
        self[:original] = data
      end
    end

    def self.interpolations
      @interpolations ||= {
        :rails_root => lambda{|style, atch| RAILS_ROOT },
        :id         => lambda{|style, atch| atch.instance.id },
        :class      => lambda{|style, atch| atch.instance.class.to_s.underscore.pluralize },
        :style      => lambda{|style, atch| style.to_s },
        :attachment => lambda{|style, atch| atch.name.to_s.pluralize },
        :filename   => lambda{|style, atch| atch.original_filename },
        :basename   => lambda{|style, atch| atch.original_filename.gsub(/\..*$/, "") },
        :extension  => lambda{|style, atch| atch.original_filename.gsub(/^.*\./, "") }
      }
    end

    def interpolate style, source
      returning source.dup do |s|
        Attachment.interpolations.each do |key, proc|
          s.gsub!(/:#{key}/){ proc.call(style, self) }
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

    def to_s
      url
    end

    protected

    def is_a_file? data
      [:content_type, :original_filename, :read].map do |meth|
        data.respond_to? meth
      end.all?
    end

    def sanitize_filename filename
      File.basename(filename).gsub(/[^\w\.\_]/,'_')
    end
  end
end