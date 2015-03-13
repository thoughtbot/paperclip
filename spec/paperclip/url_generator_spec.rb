# encoding: utf-8
require 'spec_helper'

describe Paperclip::UrlGenerator do
  it "uses the given interpolator" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)

    url_generator = Paperclip::UrlGenerator.new(mock_attachment,
                                                { interpolator: mock_interpolator })
    result = url_generator.for(:style_name, {})

    assert_equal expected, result
    assert mock_interpolator.has_interpolated_attachment?(mock_attachment)
    assert mock_interpolator.has_interpolated_style_name?(:style_name)
  end

  it "uses the default URL when no file is assigned" do
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new
    default_url = "the default url"
    options = { interpolator: mock_interpolator, default_url: default_url}

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    assert mock_interpolator.has_interpolated_pattern?(default_url),
      "expected the interpolator to be passed #{default_url.inspect} but it wasn't"
  end

  it "executes the default URL lambda when no file is assigned" do
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new
    default_url = lambda {|attachment| "the #{attachment.class.name} default url" }
    options = { interpolator: mock_interpolator, default_url: default_url}

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    assert mock_interpolator.has_interpolated_pattern?("the MockAttachment default url"),
      %{expected the interpolator to be passed "the MockAttachment default url", but it wasn't}
  end

  it "executes the method named by the symbol as the default URL when no file is assigned" do
    mock_model = FakeModel.new
    mock_attachment = MockAttachment.new(model: mock_model)
    mock_interpolator = MockInterpolator.new
    default_url = :to_s
    options = { interpolator: mock_interpolator, default_url: default_url}

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    assert mock_interpolator.has_interpolated_pattern?(mock_model.to_s),
      %{expected the interpolator to be passed #{mock_model.to_s}, but it wasn't}
  end

  it "URL-escapes spaces if asked to" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {escape: true})

    assert_equal "the%20expected%20result", result
  end

  it "escapes the result of the interpolator using a method on the object, if asked to escape" do
    expected = Class.new do
      def escape
        "the escaped result"
      end
    end.new
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {escape: true})

    assert_equal "the escaped result", result
  end

  it "leaves spaces unescaped as asked to" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {escape: false})

    assert_equal "the expected result", result
  end

  it "defaults to leaving spaces unescaped" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {})

    assert_equal "the expected result", result
  end

  it "produces URLs without the updated_at value when the object does not respond to updated_at" do
    expected = "the expected result"
    mock_interpolator = MockInterpolator.new(result: expected)
    mock_attachment = MockAttachment.new(responds_to_updated_at: false)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {timestamp: true})

    assert_equal expected, result
  end

  it "produces URLs without the updated_at value when the updated_at value is nil" do
    expected = "the expected result"
    mock_interpolator = MockInterpolator.new(result: expected)
    mock_attachment = MockAttachment.new(responds_to_updated_at: true, updated_at: nil)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {timestamp: true})

    assert_equal expected, result
  end

  it "produces URLs with the updated_at when it exists" do
    expected = "the expected result"
    updated_at = 1231231234
    mock_interpolator = MockInterpolator.new(result: expected)
    mock_attachment = MockAttachment.new(updated_at: updated_at)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {timestamp: true})

    assert_equal "#{expected}?#{updated_at}", result
  end

  it "produces URLs with the updated_at when it exists, separated with a & if a ? follow by = already exists" do
    expected = "the?expected=result"
    updated_at = 1231231234
    mock_interpolator = MockInterpolator.new(result: expected)
    mock_attachment = MockAttachment.new(updated_at: updated_at)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {timestamp: true})

    assert_equal "#{expected}&#{updated_at}", result
  end

  it "produces URLs without the updated_at when told to do as much" do
    expected = "the expected result"
    updated_at = 1231231234
    mock_interpolator = MockInterpolator.new(result: expected)
    mock_attachment = MockAttachment.new(updated_at: updated_at)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {timestamp: false})

    assert_equal expected, result
  end

  it "produces the correct URL when the instance has a file name" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new(original_filename: 'exists')
    mock_interpolator = MockInterpolator.new
    options = { interpolator: mock_interpolator, url: expected}

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    assert mock_interpolator.has_interpolated_pattern?(expected),
      "expected the interpolator to be passed #{expected.inspect} but it wasn't"
  end

  describe "should be able to escape (, ), [, and ]." do
    def generate(expected, updated_at=nil)
      mock_attachment = MockAttachment.new(updated_at: updated_at)
      mock_interpolator = MockInterpolator.new(result: expected)
      options = { interpolator: mock_interpolator }
      url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
      def url_generator.respond_to(params)
        false if params == :escape
      end
      url_generator.for(:style_name, {escape: true, timestamp: !!updated_at})
    end

    it "not timestamp" do
      expected = "the(expected)result[]"
      assert_equal "the%28expected%29result%5B%5D", generate(expected)
    end

    it "timestamp" do
      expected = "the(expected)result[]"
      updated_at = 1231231234
      assert_equal "the%28expected%29result%5B%5D?#{updated_at}",
        generate(expected, updated_at)
    end
  end
end
