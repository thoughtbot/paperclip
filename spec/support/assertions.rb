module Assertions
  def assert(truthy)
    expect(truthy).to be_true
  end

  def assert_equal(expected, actual, message = nil)
    expect(actual).to(eq(expected), message)
  end

  def assert_not_equal(expected, actual, message = nil)
    expect(actual).to_not(eq(expected), message)
  end

  def assert_raises(exception_class, message = nil, &block)
    expect(&block).to raise_error(exception_class, message)
  end

  def assert_nothing_raised(&block)
    expect(&block).to_not raise_error
  end

  def assert_nil(thing)
    expect(thing).to be_nil
  end

  def assert_contains(haystack, needle)
    expect(haystack).to include(needle)
  end

  def assert_match(pattern, value)
    expect(value).to match(pattern)
  end

  def assert_file_exists(path_to_file)
    expect(path_to_file).to exist
  end

  def assert_file_not_exists(path_to_file)
    expect(path_to_file).to_not exist
  end
end
