class FakeRails
  def initialize(env, root)
    @env = env
    @root = root
  end

  attr_reader :env, :root

  def const_defined?(const)
    if const.to_sym == :Railtie
      false
    end
  end
end
