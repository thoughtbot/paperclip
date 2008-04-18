def obtain_class
  class_name = ENV['CLASS'] || ENV['class']
  @klass = Object.const_get(class_name)
end

def obtain_attachments
  name = ENV['ATTACHMENT'] || ENV['attachment']
  if !name.blank? && @klass.attachment_names.include?(name)
    [ name ]
  else
    @klass.attachment_definitions.keys
  end
end

namespace :paperclip do
  desc "Regenerates thumbnails for a given CLASS (and optional ATTACHMENT)"
  task :refresh => :environment do
    klass     = obtain_class
    instances = klass.find(:all)
    names     = obtain_attachments
    
    puts "Regenerating thumbnails for #{instances.length} instances of #{klass.name}:"
    instances.each do |instance|
      names.each do |name|
        result = if instance.send("#{ name }?")
          instance.send(name).send("post_process")
          instance.send(name).save
        else
          true
        end
        print result ? "." : "x"; $stdout.flush
      end
    end
    puts " Done."
  end
end
