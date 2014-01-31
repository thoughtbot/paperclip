require 'rubygems'
require 'tempfile'
require 'pathname'
require 'test/unit'
require 'active_record'
require 'active_record/version'
require 'active_support'
require 'active_support/core_ext'
require 'shoulda'
require 'mocha/setup'
require 'bourne'
require 'shoulda/context'
require 'mime/types'
require 'pathname'
require 'ostruct'

begin
  require 'pry'
rescue LoadError
  # Pry is not available, just ignore.
end

puts "Testing against version #{ActiveRecord::VERSION::STRING}"

`ruby -e 'exit 0'` # Prime $? with a value.

begin
  require 'ruby-debug'
rescue LoadError
  puts "debugger disabled"
end

ROOT = Pathname(File.expand_path(File.join(File.dirname(__FILE__), '..')))

$previous_count = 0
class Test::Unit::TestCase
  def setup
    silence_warnings do
      Object.const_set(:Rails, stub('Rails'))
      Rails.stubs(:root).returns(Pathname.new(ROOT).join('tmp'))
      Rails.stubs(:env).returns('test')
      Rails.stubs(:const_defined?).with(:Railtie).returns(false)
      ActiveSupport::Deprecation.silenced = true
    end
  end

  def teardown
  end

  def report_files
    files = []
    ObjectSpace.each_object(IO){|io| files << io unless io.closed? }
    if files.count > $previous_count
      puts __name__
      puts "#{files.count} files"
      files.each do |file|
        puts "Open IO: #{file.inspect}"
      end
    end
    $previous_count = files.count
  end
end

$LOAD_PATH << File.join(ROOT, 'lib')
$LOAD_PATH << File.join(ROOT, 'lib', 'paperclip')

require File.join(ROOT, 'lib', 'paperclip.rb')

require './shoulda_macros/paperclip'

FIXTURES_DIR = File.join(File.dirname(__FILE__), "fixtures")
config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config['test'])
Paperclip.options[:logger] = ActiveRecord::Base.logger

def using_protected_attributes?
  ActiveRecord::VERSION::MAJOR < 4
end

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

  klass.class_eval do
    include Paperclip::Glue
  end

  klass.reset_column_information
  klass.connection_pool.clear_table_cache!(klass.table_name) if klass.connection_pool.respond_to?(:clear_table_cache!)
  klass.connection.schema_cache.clear_table_cache!(klass.table_name) if klass.connection.respond_to?(:schema_cache)
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
  reset_class("Dummy").tap do |klass|
    klass.has_attached_file :avatar, options
    klass.do_not_validate_attachment_file_type :avatar
    Paperclip.reset_duplicate_clash_check!
  end
end

def rebuild_meta_class_of obj, options = {}
  (class << obj; self; end).tap do |metaklass|
    metaklass.has_attached_file :avatar, options
    metaklass.do_not_validate_attachment_file_type :avatar
    Paperclip.reset_duplicate_clash_check!
  end
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

  def valid?
    errors.empty?
  end
end

def attachment(options={})
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
    assert_accepts @matcher, Dummy
  end

  should "accept an instance of that class" do
    assert_accepts @matcher, Dummy.new
  end
end

def should_reject_dummy_class
  should "reject the class" do
    assert_rejects @matcher, Dummy
  end

  should "reject an instance of that class" do
    assert_rejects @matcher, Dummy.new
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

def stringy_file
  StringIO.new('.\n')
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

def assert_file_exists(path)
  assert File.exists?(path), %(Expect "#{path}" to be exists.)
end

def assert_file_not_exists(path)
  assert !File.exists?(path), %(Expect "#{path}" to not exists.)
end

def assert_frame_dimensions(range, frames)
  frames.each_with_index do |frame, frame_index|
    frame.split('x').each_with_index do |dimension, dimension_index |
      assert range.include?(dimension.to_i), "Frame #{frame_index}[#{dimension_index}] should have been within #{range.inspect}, but was #{dimension}"
    end
  end
end
