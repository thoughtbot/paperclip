# encoding: utf-8
require './test/helper'

class FilenameCleanerTest < Test::Unit::TestCase
  should 'convert invalid characters to underscores' do
    cleaner = Paperclip::FilenameCleaner.new(/[aeiou]/)
    assert_equal "b_s_b_ll", cleaner.call("baseball")
  end

  should 'not convert anything if the character regex is nil' do
    cleaner = Paperclip::FilenameCleaner.new(nil)
    assert_equal "baseball", cleaner.call("baseball")
  end
end
