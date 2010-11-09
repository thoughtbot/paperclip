require './test/helper'

class UpfileTest < Test::Unit::TestCase
  { %w(jpg jpe jpeg) => 'image/jpeg',
    %w(tif tiff)     => 'image/tiff',
    %w(png)          => 'image/png',
    %w(gif)          => 'image/gif',
    %w(bmp)          => 'image/bmp',
    %w(txt)          => 'text/plain',
    %w(htm html)     => 'text/html',
    %w(csv)          => 'text/csv',
    %w(xml)          => 'text/xml',
    %w(css)          => 'text/css',
    %w(js)           => 'application/js',
    %w(foo)          => 'application/x-foo'
  }.each do |extensions, content_type|
    extensions.each do |extension|
      should "return a content_type of #{content_type} for a file with extension .#{extension}" do
        file = stub('file', :path => "basename.#{extension}")
        class << file
          include Paperclip::Upfile
        end

        assert_equal content_type, file.content_type
      end
    end
  end

  should "return a content_type of text/plain on a real file whose content_type is determined with the file command" do
    file = File.new(File.join(File.dirname(__FILE__), "..", "LICENSE"))
    class << file
      include Paperclip::Upfile
    end
    assert_equal 'text/plain', file.content_type
  end

  should "return a MD5 fingerprint of the file" do
    file = StringIO.new("1234567890")
    class << file
      include Paperclip::Upfile
    end
    assert_equal "e807f1fcf82d132f9bb018ca6738a19f", file.fingerprint
  end

  should "still be readable after the file fingerprints itself" do
    file = StringIO.new("1234567890")
    class << file
      include Paperclip::Upfile
    end
    file.fingerprint
    assert_equal "1234567890", file.read
  end
end
