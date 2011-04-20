def obtain_class
  class_name = ENV['CLASS'] || ENV['class']
  raise "Must specify CLASS" unless class_name
  class_name
end

def obtain_attachments(klass)
  klass = Paperclip.class_for(klass.to_s)
  name = ENV['ATTACHMENT'] || ENV['attachment']
  raise "Class #{klass.name} has no attachments specified" unless klass.respond_to?(:attachment_definitions)
  if !name.blank? && klass.attachment_definitions.keys.include?(name)
    [ name ]
  else
    klass.attachment_definitions.keys
  end
end

namespace :paperclip do
  desc "Refreshes both metadata and thumbnails."
  task :refresh => ["paperclip:refresh:metadata", "paperclip:refresh:thumbnails"]

  namespace :refresh do
    desc "Regenerates thumbnails for a given CLASS (and optional ATTACHMENT)."
    task :thumbnails => :environment do
      errors = []
      klass = obtain_class
      names = obtain_attachments(klass)
      names.each do |name|
        Paperclip.each_instance_with_attachment(klass, name) do |instance|
          result = instance.send(name).reprocess!
          errors << [instance.id, instance.errors] unless instance.errors.blank?
        end
      end
      errors.each{|e| puts "#{e.first}: #{e.last.full_messages.inspect}" }
    end

    desc "Regenerates content_type/size metadata for a given CLASS (and optional ATTACHMENT)."
    task :metadata => :environment do
      klass = obtain_class
      names = obtain_attachments(klass)
      names.each do |name|
        Paperclip.each_instance_with_attachment(klass, name) do |instance|
          if file = instance.send(name).to_file
            instance.send("#{name}_file_name=", instance.send("#{name}_file_name").strip)
            instance.send("#{name}_content_type=", file.content_type.strip)
            instance.send("#{name}_file_size=", file.size) if instance.respond_to?("#{name}_file_size")
            instance.save(false)
          else
            true
          end
        end
      end
    end
  end

  desc "Cleans out invalid attachments. Useful after you've added new validations."
  task :clean => :environment do
    klass = obtain_class
    names = obtain_attachments(klass)
    names.each do |name|
      Paperclip.each_instance_with_attachment(klass, name) do |instance|
        instance.send(name).send(:validate)
        if instance.send(name).valid?
          true
        else
          instance.send("#{name}=", nil)
          instance.save
        end
      end
    end
  end
end
