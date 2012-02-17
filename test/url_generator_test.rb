# encoding: utf-8
require './test/helper'
require 'paperclip/url_generator'

class UrlGeneratorTest < Test::Unit::TestCase
  should "use the given interpolator" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(:result => expected)

    url_generator = Paperclip::UrlGenerator.new(mock_attachment,
                                                { :interpolator => mock_interpolator })
    result = url_generator.for(:style_name, {})

    assert_equal expected, result
    assert mock_interpolator.has_interpolated_attachment?(mock_attachment)
    assert mock_interpolator.has_interpolated_style_name?(:style_name)
  end

  should "use the default URL when no file is assigned" do
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new
    default_url = "the default url"
    options = { :interpolator => mock_interpolator, :default_url => default_url}

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    assert mock_interpolator.has_interpolated_pattern?(default_url),
      "expected the interpolator to be passed #{default_url.inspect} but it wasn't"
  end

  should "execute the default URL lambda when no file is assigned" do
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new
    default_url = lambda {|attachment| "the #{attachment.class.name} default url" }
    options = { :interpolator => mock_interpolator, :default_url => default_url}

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    assert mock_interpolator.has_interpolated_pattern?("the MockAttachment default url"),
      %{expected the interpolator to be passed "the MockAttachment default url", but it wasn't}
  end

  should "execute the method named by the symbol as the default URL when no file is assigned" do
    mock_model = MockModel.new
    mock_attachment = MockAttachment.new(:model => mock_model)
    mock_interpolator = MockInterpolator.new
    default_url = :to_s
    options = { :interpolator => mock_interpolator, :default_url => default_url}

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    assert mock_interpolator.has_interpolated_pattern?(mock_model.to_s),
      %{expected the interpolator to be passed #{mock_model.to_s}, but it wasn't}
  end

  should "URL-escape spaces if asked to" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(:result => expected)
    options = { :interpolator => mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {:escape => true})

    assert_equal "the%20expected%20result", result
  end

  should "escape the result of the interpolator using a method on the object, if asked to escape" do
    expected = Class.new do
      def escape
        "the escaped result"
      end
    end.new
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(:result => expected)
    options = { :interpolator => mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {:escape => true})

    assert_equal "the escaped result", result
  end

  should "leave spaces unescaped as asked to" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(:result => expected)
    options = { :interpolator => mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {:escape => false})

    assert_equal "the expected result", result
  end

  should "default to leaving spaces unescaped" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(:result => expected)
    options = { :interpolator => mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {})

    assert_equal "the expected result", result
  end

  should "produce URLs without the updated_at value when the object does not respond to updated_at" do
    expected = "the expected result"
    mock_interpolator = MockInterpolator.new(:result => expected)
    mock_attachment = MockAttachment.new(:responds_to_updated_at => false)
    options = { :interpolator => mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {:timestamp => true})

    assert_equal expected, result
  end

  should "produce URLs without the updated_at value when the updated_at value is nil" do
    expected = "the expected result"
    mock_interpolator = MockInterpolator.new(:result => expected)
    mock_attachment = MockAttachment.new(:responds_to_updated_at => true, :updated_at => nil)
    options = { :interpolator => mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {:timestamp => true})

    assert_equal expected, result
  end

  should "produce URLs with the updated_at when it exists" do
    expected = "the expected result"
    updated_at = 1231231234
    mock_interpolator = MockInterpolator.new(:result => expected)
    mock_attachment = MockAttachment.new(:updated_at => updated_at)
    options = { :interpolator => mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {:timestamp => true})

    assert_equal "#{expected}?#{updated_at}", result
  end

  should "produce URLs with the updated_at when it exists, separated with a & if a ? follow by = already exists" do
    expected = "the?expected=result"
    updated_at = 1231231234
    mock_interpolator = MockInterpolator.new(:result => expected)
    mock_attachment = MockAttachment.new(:updated_at => updated_at)
    options = { :interpolator => mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {:timestamp => true})

    assert_equal "#{expected}&#{updated_at}", result
  end

  should "produce URLs without the updated_at when told to do as much" do
    expected = "the expected result"
    updated_at = 1231231234
    mock_interpolator = MockInterpolator.new(:result => expected)
    mock_attachment = MockAttachment.new(:updated_at => updated_at)
    options = { :interpolator => mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {:timestamp => false})

    assert_equal expected, result
  end

  should "produce the correct URL when the instance has a file name" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new(:original_filename => 'exists')
    mock_interpolator = MockInterpolator.new
    options = { :interpolator => mock_interpolator, :url => expected}

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    assert mock_interpolator.has_interpolated_pattern?(expected),
      "expected the interpolator to be passed #{expected.inspect} but it wasn't"
  end
end
