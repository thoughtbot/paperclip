class PaperclipGenerator < Rails::Generator::NamedBase
  attr_accessor :attachments
 
  def initialize(*args)
    super(*args)
    @attachments = args
  end
 
  def manifest
    record do |m|
      m.migration_template "paperclip_migration.rb", File.join('db', 'migrate')
    end
  end 
 
end