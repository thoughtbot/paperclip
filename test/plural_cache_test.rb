require './test/helper'

class PluralCacheTest < Test::Unit::TestCase
  should 'cache pluralizations' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "box"

    word.expects(:pluralize).returns("boxes").once

    cache.pluralize(word)
    cache.pluralize(word)
  end

  should 'cache pluralizations and underscores' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "BigBox"

    word.expects(:pluralize).returns(word).once
    word.expects(:underscore).returns(word).once

    cache.underscore_and_pluralize(word)
    cache.underscore_and_pluralize(word)
  end

  should 'pluralize words' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "box"
    assert_equal "boxes", cache.pluralize(word)
  end

  should 'pluralize and underscore words' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "BigBox"
    assert_equal "big_boxes", cache.underscore_and_pluralize(word)
  end
end
