require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'tempfile'

require 'active_record'
require 'ruby-debug'

ROOT       = File.join(File.dirname(__FILE__), '..')
RAILS_ROOT = ROOT

$LOAD_PATH << File.join(ROOT, 'lib')
$LOAD_PATH << File.join(ROOT, 'lib', 'paperclip')

require File.join(ROOT, 'lib', 'paperclip.rb')

class String
  unless methods.include? :pluralize
    def pluralize
      "#{self}s"
    end
  end
end

FIXTURES_DIR = File.join(File.dirname(__FILE__), "fixtures") 
config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['RAILS_ENV'] || 'test'])

def rebuild_model options = {}
  ActiveRecord::Base.connection.create_table :dummies, :force => true do |table|
    table.column :avatar_file_name, :string
    table.column :avatar_content_type, :string
    table.column :avatar_file_size, :integer
  end

  ActiveRecord::Base.send(:include, Paperclip)
  Object.send(:remove_const, "Dummy") rescue nil
  Object.const_set("Dummy", Class.new(ActiveRecord::Base))
  Dummy.class_eval do
    include Paperclip
    has_attached_file :avatar, options
  end
end
