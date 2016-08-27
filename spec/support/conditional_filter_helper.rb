module ConditionalFilterHelper
  def use_accelerate_endpoint_option_is_available_in_aws_sdk?
    (Gem::Version.new(Aws::VERSION) >= Gem::Version.new("2.3.0"))
  end
end
