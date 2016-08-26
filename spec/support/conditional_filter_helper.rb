module ConditionalFilterHelper
  def aws_accelerate_available?
    (Gem::Version.new(Aws::VERSION) >= Gem::Version.new("2.3.0"))
  end
end
