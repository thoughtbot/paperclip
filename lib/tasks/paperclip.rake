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
  klass = obtain_class
  names = obtain_attachments
  ids   = klass.connection.select_values(klass.send(:construct_finder_sql, :select => 'id'))

  ids.each do |id|
    instance = klass.find(id)
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
  desc "Refreshes both metadata and thumbnails."
  task :refresh => ["paperclip:refresh:metadata", "paperclip:refresh:thumbnails"]

  namespace :refresh do
    desc "Regenerates thumbnails for a given CLASS (and optional ATTACHMENT)."
    task :thumbnails => :environment do
      errors = []
      for_all_attachments do |instance, name|
        result = instance.send(name).reprocess!
        errors << [instance.id, instance.errors] unless instance.errors.blank?
        result
      end
      errors.each{|e| puts "#{e.first}: #{e.last.full_messages.inspect}" }
    end

    desc "Regenerates content_type/size/fingerprint/hexdigests metadata for a given CLASS (and optional ATTACHMENT)."
    task :metadata => :environment do
      for_all_attachments do |instance, name|
        if file = instance.send(name).to_file
          instance.send("#{name}_file_name=", instance.send("#{name}_file_name").strip)
          instance.send("#{name}_content_type=", file.content_type.strip)
          instance.send("#{name}_file_size=", file.size) if instance.respond_to?("#{name}_file_size")
          instance.send("#{name}_fingerprint=", file.fingerprint) if instance.respond_to?("#{name}_fingerprint")
          instance.send("#{name}_file_md5_hexdigest=", file.md5_hexdigest) if instance.respond_to?("#{name}_file_md5_hexdigest")
          instance.send("#{name}_file_rmd160_hexdigest=", file.rmd160_hexdigest) if instance.respond_to?("#{name}_file_rmd160_hexdigest")
          instance.send("#{name}_file_sha1_hexdigest=", file.sha1_hexdigest) if instance.respond_to?("#{name}_file_sha1_hexdigest")
          instance.send("#{name}_file_sha256_hexdigest=", file.sha256_hexdigest) if instance.respond_to?("#{name}_file_sha256_hexdigest")
          instance.send("#{name}_file_sha384_hexdigest=", file.sha384_hexdigest) if instance.respond_to?("#{name}_file_sha384_hexdigest")
          instance.send("#{name}_file_sha512_hexdigest=", file.sha512_hexdigest) if instance.respond_to?("#{name}_file_sha512_hexdigest")
          instance.send("#{name}_file_tiger_hexdigest=", file.tiger_hexdigest) if instance.respond_to?("#{name}_file_tiger_hexdigest")
          instance.send("#{name}_file_whirlpool_hexdigest=", file.whirlpool_hexdigest) if instance.respond_to?("#{name}_file_whirlpool_hexdigest")
          instance.save(false)
        else
          true
        end
      end
    end
  end

  desc "Cleans out invalid attachments. Useful after you've added new validations."
  task :clean => :environment do
    for_all_attachments do |instance, name|
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
