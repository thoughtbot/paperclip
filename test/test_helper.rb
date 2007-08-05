require 'rubygems'
require 'test/unit'
require 'active_record'
require 'active_record/fixtures'
require 'fileutils'
require 'pp'

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['RAILS_ENV'] || 'test'])

Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"
$LOAD_PATH.unshift(Test::Unit::TestCase.fixture_path)

RAILS_ROOT = "test" unless Object.const_defined? "RAILS_ROOT"

class Test::Unit::TestCase #:nodoc:
  def create_fixtures(*table_names)
    if block_given?
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names) { yield }
    else
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names)
    end
  end
  
	def self.load_all_fixtures
		all_fixtures = Dir.glob("#{File.dirname(__FILE__)}/fixtures/*.yml").collect do |f|
			puts "Loading fixture '#{f}'"
			File.basename(f).gsub(/\.yml$/, "").to_sym
		end
		Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, all_fixtures)
	end

  # Turn off transactional fixtures if you're working with MyISAM tables in MySQL
  self.use_transactional_fixtures = true
  
  # Instantiated fixtures are slow, but give you @david where you otherwise would need people(:david)
  self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...
end