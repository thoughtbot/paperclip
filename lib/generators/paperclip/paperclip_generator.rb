class PaperclipGenerator < Rails::Generators::Base
  include Rails::Generators::Migration

  desc "Create a migration to add paperclip-specific fields to your model."

  argument :attachment_class, :required => true, :type => :string, :desc => "The class to migrate.",
           :banner => "ClassName"
  argument :attachment_names, :required => true, :type => :array, :desc => "The names of the attachment(s) to add.",
           :banner => "attachment_one attachment_two attachment_three ..."

  def self.source_root
    @source_root ||= File.expand_path('../templates', __FILE__)
  end

  def generate_migration
    migration_template "paperclip_migration.rb.erb", "db/migrate/#{migration_file_name}"
  end

  protected

  def migration_name
    "add_attachment_#{attachment_names.join("_")}_to_#{attachment_class.underscore}"
  end

  def migration_file_name
    "#{migration_name}.rb"
  end

  def migration_class_name
    migration_name.camelize
  end

  def self.next_migration_number(dirname) #:nodoc:
    Time.now.strftime("%Y%m%d%H%M%S")
  end

end
