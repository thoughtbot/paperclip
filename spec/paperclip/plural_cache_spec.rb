require 'spec_helper'

describe 'Plural cache' do
  it 'caches pluralizations' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "box"

    word.expects(:pluralize).returns("boxes").once

    cache.pluralize(word)
    cache.pluralize(word)
  end

  it 'caches pluralizations and underscores' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "BigBox"

    word.expects(:pluralize).returns(word).once
    word.expects(:underscore).returns(word).once

    cache.underscore_and_pluralize(word)
    cache.underscore_and_pluralize(word)
  end

  it 'pluralizes words' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "box"
    assert_equal "boxes", cache.pluralize(word)
  end

  it 'pluralizes and underscore words' do
    cache = Paperclip::Interpolations::PluralCache.new
    word = "BigBox"
    assert_equal "big_boxes", cache.underscore_and_pluralize(word)
  end
end
