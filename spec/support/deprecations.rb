RSpec.configure do |config|
  config.before(:all) do
    ActiveSupport::Deprecation.silenced = true
  end
  config.before(:each) do
    Paperclip::Deprecations.stubs(:active_model_version).returns("4.2")
    Paperclip::Deprecations.stubs(:aws_sdk_version).returns("2.0.0")
  end
end
