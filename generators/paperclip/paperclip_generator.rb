class PaperclipGenerator < Rails::Generator::NamedBase
  attr_accessor :attachments, :migration_name
 
  def initialize(args, options = {})
    super
    @class_name, @attachments = args
  end
 
  def manifest
    file_name = "add_paperclip_attachment_columns_to_#{@class_name.underscore.camelize}"
    @migration_name = file_name.camelize
    record do |m|
      m.migration_template "paperclip_migration.rb",
                           File.join('db', 'migrate'),
                           :migration_file_name => file_name
    end
  end 
 
end