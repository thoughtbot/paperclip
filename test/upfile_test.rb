require './test/helper'

class UpfileTest < Test::Unit::TestCase
  { %w(jpg jpe jpeg) => 'image/jpeg',
    %w(tif tiff)     => 'image/tiff',
    %w(png)          => 'image/png',
    %w(gif)          => 'image/gif',
    %w(bmp)          => 'image/bmp',
    %w(svg)          => 'image/svg+xml',
    %w(txt)          => 'text/plain',
    %w(htm html)     => 'text/html',
    %w(csv)          => 'text/csv',
    %w(xml)          => 'application/xml',
    %w(css)          => 'text/css',
    %w(js)           => 'application/javascript',
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

  { '5k.png'       => 'image/png',
    'animated.gif' => 'image/gif',
    'text.txt'     => 'text/plain',
    'twopage.pdf'  => 'application/pdf'
  }.each do |filename, content_type|
    should "return a content type of #{content_type} from a file command for file #{filename}" do
      file = File.new(File.join(File.dirname(__FILE__), "fixtures", filename))
      class << file
        include Paperclip::Upfile
      end

      assert_equal content_type, file.type_from_file_command
    end
  end

end
