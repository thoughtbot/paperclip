begin
  require "active_job"
rescue LoadError
  raise LoadError,
    "To use background processing you have to include 'active_job' in load path"
end

module Paperclip
  class ProcessJob < ActiveJob::Base
    def perform(instance, attachment_name)
      attachment = instance.send(attachment_name)
      styles = attachment.options[:process_in_background]
      attachment.generate_style_files(*styles)

      if attachment.instance_respond_to?(:processing_in_background)
        attachment.instance_write(:processing_in_background, false)
        instance.save!
      end
    end
  end
end
