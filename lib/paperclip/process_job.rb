begin
  require "active_job"
rescue LoadError
  raise LoadError, "To use background processing you have to include 'active_job' in load path"
end

module Paperclip
  class ProcessJob < ActiveJob::Base
    def perform(instance, attachment_name)
      attachment = instance.send(attachment_name)
      styles = attachment.options[:process_in_background]
      attachment.generate_style_files(*styles)
    end
  end
end
