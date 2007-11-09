class << Test::Unit::TestCase
  def context name, &block
    (@contexts ||= [])       << name
    (@context_blocks ||= []) << block
    saved_setups    = (@context_setups ||= []).dup
    saved_teardowns = (@context_teardowns ||= []).dup

    self.instance_eval(&block)

    @context_setups     = saved_setups
    @context_teardowns  = saved_teardowns
    @contexts.pop
    @context_blocks.pop
  end

  def setup &block
    @context_setups << block
  end

  def teardown &block
    @context_teardowns << block
  end

  def should name, &test
    context_setups    = @context_setups.dup
    context_teardowns = @context_teardowns.dup
    define_method(["test:", @contexts, "should", name].join(" ")) do
      context_setups.each { |setup| self.instance_eval(&setup) }
      self.instance_eval(&test)
      context_teardowns.each { |teardown| self.instance_eval(&teardown) }
    end
  end
end