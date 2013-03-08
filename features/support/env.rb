require 'aruba/cucumber'
require 'capybara/cucumber'
require 'test/unit/assertions'

$CUCUMBER=1

World(Test::Unit::Assertions)

Before do
  @aruba_timeout_seconds = 120

  if ENV['DEBUG']
    @puts = true
    @announce_stdout = true
    @announce_stderr = true
    @announce_cmd = true
    @announce_dir = true
    @announce_env = true
  end
end
