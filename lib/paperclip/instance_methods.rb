module Paperclip
  module InstanceMethods #:nodoc:
    def attachment_for name
      @_paperclip_attachments ||= {}
      @_paperclip_attachments[name] ||= Attachment.new(name, self, attachment_definitions[name])
    end

    def each_attachment
      self.attachment_definitions.each do |name, definition|
        yield(name, attachment_for(name))
      end
    end

    def save_attached_files
      Paperclip.log("Saving attachments.")
      each_attachment do |name, attachment|
        attachment.send(:save)
      end
    end

    def destroy_attached_files
      Paperclip.log("Deleting attachments.")
      each_attachment do |name, attachment|
        attachment.send(:flush_deletes)
      end
    end

    def prepare_for_destroy
      Paperclip.log("Scheduling attachments for deletion.")
      each_attachment do |name, attachment|
        attachment.send(:queue_all_for_delete)
      end
    end
  end
end
