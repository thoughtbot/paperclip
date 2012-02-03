require 'rubygems'
require 'tempfile'
require 'pathname'
require 'test/unit'

require 'shoulda'
require 'mocha'

require 'active_record'
require 'active_record/version'
require 'active_support'
require 'mime/types'
require 'pathname'

require 'pathname'

puts "Testing against version #{ActiveRecord::VERSION::STRING}"

`ruby -e 'exit 0'` # Prime $? with a value.

begin
  require 'ruby-debug'
rescue LoadError => e
  puts "debugger disabled"
end

ROOT = Pathname(File.expand_path(File.join(File.dirname(__FILE__), '..')))

def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = old_verbose
end

class Test::Unit::TestCase
  def setup
    silence_warnings do
      Object.const_set(:Rails, stub('Rails', :root => ROOT, :env => 'test'))
    end
  end
end

$LOAD_PATH << File.join(ROOT, 'lib')
$LOAD_PATH << File.join(ROOT, 'lib', 'paperclip')

require File.join(ROOT, 'lib', 'paperclip.rb')

require './shoulda_macros/paperclip'

FIXTURES_DIR = File.join(File.dirname(__FILE__), "fixtures")
config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config['test'])
Paperclip.options[:logger] = ActiveRecord::Base.logger

def require_everything_in_directory(directory_name)
  Dir[File.join(File.dirname(__FILE__), directory_name, '*')].each do |f|
    require f
  end
end

require_everything_in_directory('support')

def reset_class class_name
  ActiveRecord::Base.send(:include, Paperclip::Glue)
  Object.send(:remove_const, class_name) rescue nil
  klass = Object.const_set(class_name, Class.new(ActiveRecord::Base))
  klass.class_eval{ include Paperclip::Glue }
  klass
end

def reset_table table_name, &block
  block ||= lambda { |table| true }
  ActiveRecord::Base.connection.create_table :dummies, {:force => true}, &block
end

def modify_table table_name, &block
  ActiveRecord::Base.connection.change_table :dummies, &block
end

def rebuild_model options = {}
  ActiveRecord::Base.connection.create_table :dummies, :force => true do |table|
    table.column :title, :string
    table.column :other, :string
    table.column :avatar_file_name, :string
    table.column :avatar_content_type, :string
    table.column :avatar_file_size, :integer
    table.column :avatar_updated_at, :datetime
    table.column :avatar_fingerprint, :string
  end
  rebuild_class options
end

def rebuild_class options = {}
  ActiveRecord::Base.send(:include, Paperclip::Glue)
  Object.send(:remove_const, "Dummy") rescue nil
  Object.const_set("Dummy", Class.new(ActiveRecord::Base))
  Paperclip.reset_duplicate_clash_check!
  Dummy.class_eval do
    include Paperclip::Glue
    has_attached_file :avatar, options
  end
  Dummy.reset_column_information
end

class FakeModel
  attr_accessor :avatar_file_name,
                :avatar_file_size,
                :avatar_updated_at,
                :avatar_content_type,
                :avatar_fingerprint,
                :id

  def errors
    @errors ||= []
  end

  def run_paperclip_callbacks name, *args
  end

end

def attachment options
  Paperclip::Attachment.new(:avatar, FakeModel.new, options)
end

def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = old_verbose
end

def should_accept_dummy_class
  should "accept the class" do
    assert_accepts @matcher, @dummy_class
  end

  should "accept an instance of that class" do
    assert_accepts @matcher, @dummy_class.new
  end
end

def should_reject_dummy_class
  should "reject the class" do
    assert_rejects @matcher, @dummy_class
  end

  should "reject an instance of that class" do
    assert_rejects @matcher, @dummy_class.new
  end
end

def with_exitstatus_returning(code)
  saved_exitstatus = $?.nil? ? 0 : $?.exitstatus
  begin
    `ruby -e 'exit #{code.to_i}'`
    yield
  ensure
    `ruby -e 'exit #{saved_exitstatus.to_i}'`
  end
end

def fixture_file(filename)
 File.join(File.dirname(__FILE__), 'fixtures', filename)
end

def assert_success_response(url)
  Net::HTTP.get_response(URI.parse(url)) do |response|
    assert_equal "200", response.code,
      "Expected HTTP response code 200, got #{response.code}"
  end
end

def assert_not_found_response(url)
  Net::HTTP.get_response(URI.parse(url)) do |response|
    assert_equal "404", response.code,
      "Expected HTTP response code 404, got #{response.code}"
  end
end
