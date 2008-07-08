def obtain_class
  class_name = ENV['CLASS'] || ENV['class']
  raise "Must specify CLASS" unless class_name
  @klass = Object.const_get(class_name)
end

def obtain_attachments
  name = ENV['ATTACHMENT'] || ENV['attachment']
  raise "Class #{@klass.name} has no attachments specified" unless @klass.respond_to?(:attachment_definitions)
  if !name.blank? && @klass.attachment_definitions.keys.include?(name)
    [ name ]
  else
    @klass.attachment_definitions.keys
  end
end

def for_all_attachments
  klass     = obtain_class
  names     = obtain_attachments
  instances = klass.find(:all)

  instances.each do |instance|
    names.each do |name|
      result = if instance.send("#{ name }?")
                 yield(instance, name)
               else
                 true
               end
      print result ? "." : "x"; $stdout.flush
    end
  end
  puts " Done."
end

namespace :paperclip do
  desc "Regenerates thumbnails for a given CLASS (and optional ATTACHMENT)"
  task :refresh => :environment do
    for_all_attachments do |instance, name|
      instance.send(name).reprocess!
      instance.send(name).save
    end
  end

  desc "Cleans out invalid attachments. Useful after you've added new validations."
  task :clean => :environment do
    for_all_attachments do |instance, name|
      if instance.valid?
        true
      else
        instance.send("#{name}=", nil)
        instance.save
      end
    end
  end
end
