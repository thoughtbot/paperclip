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
    
    # Sets the file managed by this instance. It also creates the thumbnails if the attachment is an image.
    def assign uploaded_file
      return destroy if uploaded_file.nil?
      return unless is_a_file? uploaded_file

      self.original_filename  = sanitize_filename(uploaded_file.original_filename)
      self.content_type       = uploaded_file.content_type
      self.original_file_size = uploaded_file.size
      self[:original]         = uploaded_file.read
      @dirty                  = true
      @delete_on_save         = false

      convert( self[:original] )
    end

    def [](style) #:nodoc:
      @files[style]
    end

    def []=(style, data) #:nodoc:
      @dirty = true
      @files[style] = data
    end

    def clear_files #:nodoc:
      @files = {}
      definition.styles.each{|style, geo| self[style] = nil }
      @dirty = false
    end

    # Iterates over the files that are stored in memory and hands them to the
    # supplied block. If no assignment has happened since either the object
    # was instantiated or the last time it was saved, +nil+ will be passed as
    # the data argument.
    def each_unsaved
      @files.each do |style, data|
        yield( style, data ) if data
      end
    end
    
    def styles
      @files.keys
    end

    # Returns true if the attachment has been assigned and not saved.
    def dirty?
      @dirty
    end

    # Runs any validations that have been defined on the attachment.
    def valid?
      definition.validations.each do |validation, constraints|
        send("validate_#{validation}", *constraints)
      end
      errors.uniq!.empty?
    end

    # Writes (or deletes, if +nil+) the attachment. This is called automatically
    # when the active record is saved; you do not need to call this yourself.
    def save
      write_attachment  if dirty?
      delete_attachment if @delete_on_save
      @delete_on_save = false
      clear_files
    end

    # Queues up the attachment for destruction, but does not actually delete.
    # The attachment will be deleted when the record is saved.
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

    # Immediately destroys the attachment. Typically called as an ActiveRecord
    # callback on destroy. You shold not need to call this.
    def destroy!
      delete_attachment if definition.delete_on_destroy
    end

    # Returns the public-facing URL of the attachment. If this record has not
    # been saved or does not have an attachment, this method will return the
    # "missing" url, which can be used to supply a default. This is what should
    # be supplied to the +image_tag+ helper.
    def url style = nil
      style ||= definition.default_style
      pattern = if original_filename && instance.id
        definition.url
      else
        definition.missing_url
      end
      interpolate( style, pattern )
    end

    # Returns the data contained by the attachment of a particular style. This
    # should be used if you need to restrict permissions internally to the app.
    def read style = nil
      style ||= definition.default_style
      self[style] ? self[style] : read_attachment(style)  
    end

    # Sets errors if there must be an attachment but isn't.
    def validate_existence *constraints
      definition.styles.keys.each do |style|
        errors << "requires a valid #{style} file." unless attachment_exists?(style)
      end
    end

    # Sets errors if the file does not meet the file size constraints.
    def validate_size *constraints
      errors << "file too large. Must be under #{constraints.last} bytes." if original_file_size > constraints.last
      errors << "file too small. Must be over #{constraints.first} bytes." if original_file_size <= constraints.first
    end

    # Returns true if all the files exist.
    def exists?(style)
      style ||= definition.default_style
      attachment_exists?(style)
    end

    # Generates the thumbnails from the data supplied. Following this call, the data will
    # be available from for_attached_files.
    def convert data
      begin
        definition.styles.each do |style, geometry|
          self[style] = Thumbnail.make(geometry, data, definition.whiny_thumbnails)
        end
      rescue PaperclipError => e
        errors << e.message
        clear_files
        self[:original] = data
      end
    end

    # Returns a hash of procs that will perform the various interpolations for
    # the path, url, and missing_url attachment options. The procs are used as
    # arguments to gsub!, so the used will be replaced with the return value
    # of the proc. You can add to this list by assigning to the hash:
    #   Paperclip::Attachment.interpolations[:content_type] = lambda{|style, attachment| attachment.content_type }
    #   ...
    #   attachment.interpolate("original", ":content_type")
    #   # => "image/jpeg"
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

    # Searches for patterns in +source+ string supplied and replaces them with values
    # returned by the procs in the interpolations hash.
    def interpolate style, source
      returning source.dup do |s|
        Attachment.interpolations.each do |key, proc|
          s.gsub!(/:#{key}/) do
            proc.call(style, self) rescue ":#{key}"
          end
        end
      end
    end

    # Sets the *_file_name column on the activerecord for this attachment
    def original_filename= new_name
      instance["#{name}_file_name"] = @original_filename = new_name
    end
    
    # Sets the *_content_type column on the activerecord for this attachment
    def content_type= new_type
      instance["#{name}_content_type"] = @content_type = new_type
    end

    # Sets the *_file_size column on the activerecord for this attachment
    def original_file_size= new_size
      instance["#{name}_file_size"] = @original_file_size = new_size
    end

    def to_s
      url
    end

    protected

    def is_a_file? data #:nodoc:
      [:content_type, :original_filename, :read].map do |meth|
        data.respond_to? meth
      end.all?
    end

    def sanitize_filename filename #:nodoc:
      File.basename(filename).gsub(/[^\w\.\_\-]/,'_')
    end
  end
end
