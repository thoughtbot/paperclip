module Paperclip
  module Task
    def self.obtain_class
      class_name = ENV['CLASS'] || ENV['class']
      raise "Must specify CLASS" unless class_name
      class_name
    end

    def self.obtain_attachments(klass)
      klass = Paperclip.class_for(klass.to_s)
      name = ENV['ATTACHMENT'] || ENV['attachment']
      raise "Class #{klass.name} has no attachments specified" unless klass.respond_to?(:attachment_definitions)
      if !name.blank? && klass.attachment_definitions.keys.map(&:to_s).include?(name.to_s)
        [ name ]
      else
        klass.attachment_definitions.keys
      end
    end

    # Ripe for refactoring, but I'd rather not open Hash
    def self.recursively_symbolize_keys!(hsh)
      hsh.symbolize_keys!
      hsh.each do |k, v|
        if v.is_a? Hash
          recursively_symbolize_keys!(v)
        end
      end
      hsh
    end
  end
end

namespace :paperclip do
  desc "Refreshes both metadata and thumbnails."
  task :refresh => ["paperclip:refresh:metadata", "paperclip:refresh:thumbnails"]

  desc <<-EOD
Create files for a given CLASS (and optional ATTACHMENT) with the options in
config/new_paperclip_options.yml. These are merged onto the model's current
options. The YML file is run through ERB first (e.g. if you use one of the
common tricks to hide some API secrets on the production machine)

Models are not actually changed. This task is meant to be a step in the
process of setting new options for paperclip, ensuring that hashes are
correct or a new storage method contains the files before cutting over a
production system.

The envisioned usage of this task is:
  1. Put options changes in config/new_paperclip_options.yml
  2. Disable uploads of the relevant CLASS
  3. Run "bundle exec rake CLASS=MyModel paperclip:change_options
  4. Re-enable uploads and set the new options in the model or initializer
  EOD
  task :change_options => :environment do
    begin
    # Don't begin/rescue this because errors should terminate anyway
    yml_text = ERB.new(File.read(File.join(Rails.root, 'config', 'new_paperclip_options.yml'))).result
    new_options = Paperclip::Task.recursively_symbolize_keys!(YAML.load(yml_text))

    klass = Paperclip::Task.obtain_class
    names = Paperclip::Task.obtain_attachments(klass)
    names.each do |name|
      Paperclip.each_instance_with_attachment(klass, name) do |instance|
        attachment = instance.send(name)
        if file = Paperclip.io_adapters.for(attachment)
          options = attachment.options
          # Check that :path is different at least, unless FORCE=true
          unless ENV['FORCE'] || ENV['force'] ||
                 (new_options[:url] && options[:url] != new_options[:url]) ||
                 (new_options[:path] && options[:path] != new_options[:path])
            raise <<-EOD
Both URL #{options[:url]} and path #{options[:path]} are unchanged.
If you're willing to risk file overwrites, re-run the task with FORCE=true
            EOD
          end

          # Create a new instance to handle storage type changes/initialization
          options.merge!(new_options)
          new_att = Paperclip::Attachment.new(name, instance, options)
          new_att.assign(file)
          unless new_att.save
            puts "errors while changing options for #{klass} ID #{instance.id}:"
            puts " #{instance.errors.full_messages.join "\n "}\n"
          end
        end
      end
    end
    rescue => e
      puts e.inspect
      puts e.backtrace
    end
  end

  namespace :refresh do
    desc "Regenerates thumbnails for a given CLASS (and optional ATTACHMENT and STYLES splitted by comma)."
    task :thumbnails => :environment do
      klass = Paperclip::Task.obtain_class
      names = Paperclip::Task.obtain_attachments(klass)
      styles = (ENV['STYLES'] || ENV['styles'] || '').split(',').map(&:to_sym)
      names.each do |name|
        Paperclip.each_instance_with_attachment(klass, name) do |instance|
          instance.send(name).reprocess!(*styles)
          unless instance.errors.blank?
            puts "errors while processing #{klass} ID #{instance.id}:"
            puts " " + instance.errors.full_messages.join("\n ") + "\n"
          end
        end
      end
    end

    desc "Regenerates content_type/size metadata for a given CLASS (and optional ATTACHMENT)."
    task :metadata => :environment do
      klass = Paperclip::Task.obtain_class
      names = Paperclip::Task.obtain_attachments(klass)
      names.each do |name|
        Paperclip.each_instance_with_attachment(klass, name) do |instance|
          if file = Paperclip.io_adapters.for(instance.send(name))
            instance.send("#{name}_file_name=", instance.send("#{name}_file_name").strip)
            instance.send("#{name}_content_type=", file.content_type.to_s.strip)
            instance.send("#{name}_file_size=", file.size) if instance.respond_to?("#{name}_file_size")
            instance.save(:validate => false)
          else
            true
          end
        end
      end
    end

    desc "Regenerates missing thumbnail styles for all classes using Paperclip."
    task :missing_styles => :environment do
      # Force loading all model classes to never miss any has_attached_file declaration:
      Dir[Rails.root + 'app/models/**/*.rb'].each { |path| load path }
      Paperclip.missing_attachments_styles.each do |klass, attachment_definitions|
        attachment_definitions.each do |attachment_name, missing_styles|
          puts "Regenerating #{klass} -> #{attachment_name} -> #{missing_styles.inspect}"
          ENV['CLASS'] = klass.to_s
          ENV['ATTACHMENT'] = attachment_name.to_s
          ENV['STYLES'] = missing_styles.join(',')
          Rake::Task['paperclip:refresh:thumbnails'].execute
        end
      end
      Paperclip.save_current_attachments_styles!
    end
  end

  desc "Cleans out invalid attachments. Useful after you've added new validations."
  task :clean => :environment do
    klass = Paperclip::Task.obtain_class
    names = Paperclip::Task.obtain_attachments(klass)
    names.each do |name|
      Paperclip.each_instance_with_attachment(klass, name) do |instance|
        unless instance.valid?
          attributes = %w(file_size file_name content_type).map{ |suffix| "#{name}_#{suffix}".to_sym }
          if attributes.any?{ |attribute| instance.errors[attribute].present? }
            instance.send("#{name}=", nil)
            instance.save(:validate => false)
          end
        end
      end
    end
  end
end
