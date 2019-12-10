class FakeRails
  def initialize(env, root)
    @env = env
    @root = root
  end

  attr_accessor :env, :root

  def const_defined?(_const)
    false
  end
end
