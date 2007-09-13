require 'environment'

def obtain_class
  class_name = ENV['CLASS'] || ENV['class']
  @klass = eval(class_name)
end

def obtain_attachments
  name = ENV['ATTACHMENT'] || ENV['attachment']
  if !name.blank? && @klass.attachment_names.include?(name)
    [ name ]
  else
    @klass.attachment_names
  end
end

namespace :paperclip do
  desc "Regenerates thumbnails for a given CLASS (and optional ATTACHMENT)"
  task :refresh do
    klass     = obtain_class
    instances = klass.find(:all)
    names     = obtain_attachments
    
    puts "Regenerating thumbnails for #{instances.length} instances:"
    instances.each do |instance|
      names.each do |name|
        instance.send("process_#{name}_thumbnails")
      end
      print instance.save ? "." : "x"; $stdout.flush
    end
    puts " Done."
  end
end