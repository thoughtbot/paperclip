require 'spec_helper'

describe 'Plural cache' do
  it 'cache pluralizations' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "box"

    word.expects(:pluralize).returns("boxes").once

    cache.pluralize(word)
    cache.pluralize(word)
  end

  it 'cache pluralizations and underscores' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "BigBox"

    word.expects(:pluralize).returns(word).once
    word.expects(:underscore).returns(word).once

    cache.underscore_and_pluralize(word)
    cache.underscore_and_pluralize(word)
  end

  it 'pluralize words' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "box"
    assert_equal "boxes", cache.pluralize(word)
  end

  it 'pluralize and underscore words' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "BigBox"
    assert_equal "big_boxes", cache.underscore_and_pluralize(word)
  end
end
