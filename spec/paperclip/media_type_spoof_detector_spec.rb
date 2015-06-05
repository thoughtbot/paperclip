require 'spec_helper'

describe Paperclip::MediaTypeSpoofDetector do
  it 'rejects a file that is named .html and identifies as PNG' do
    file = File.open(fixture_file("5k.png"))
    assert Paperclip::MediaTypeSpoofDetector.using(file, "5k.html", "image/png").spoofed?
  end

  it 'does not reject a file that is named .jpg and identifies as PNG' do
    file = File.open(fixture_file("5k.png"))
    assert ! Paperclip::MediaTypeSpoofDetector.using(file, "5k.jpg", "image/png").spoofed?
  end

  it 'does not reject a file that is named .html and identifies as HTML' do
    file = File.open(fixture_file("empty.html"))
    assert ! Paperclip::MediaTypeSpoofDetector.using(file, "empty.html", "text/html").spoofed?
  end

  it 'does not reject a file that does not have a name' do
    file = File.open(fixture_file("empty.html"))
    assert ! Paperclip::MediaTypeSpoofDetector.using(file, "", "").spoofed?
  end

  it 'does not reject a file that does have an extension' do
    file = File.open(fixture_file("empty.html"))
    assert ! Paperclip::MediaTypeSpoofDetector.using(file, "data", "").spoofed?
  end

  it 'does not reject when the supplied file is an IOAdapter' do
    adapter = Paperclip.io_adapters.for(File.new(fixture_file("5k.png")))
    assert ! Paperclip::MediaTypeSpoofDetector.using(adapter, adapter.original_filename, adapter.content_type).spoofed?
  end

  it 'does not reject when the extension => content_type is in :content_type_mappings' do
    begin
      Paperclip.options[:content_type_mappings] = { pem: "text/plain" }
      file = Tempfile.open(["test", ".PEM"])
      file.puts "Certificate!"
      file.close
      adapter = Paperclip.io_adapters.for(File.new(file.path));
      assert ! Paperclip::MediaTypeSpoofDetector.using(adapter, adapter.original_filename, adapter.content_type).spoofed?
    ensure
      Paperclip.options[:content_type_mappings] = {}
    end
  end

  it "rejects a file if named .html and is as HTML, but we're told JPG" do
    file = File.open(fixture_file("empty.html"))
    assert Paperclip::MediaTypeSpoofDetector.using(file, "empty.html", "image/jpg").spoofed?
  end

  it "does not reject if content_type is empty but otherwise checks out" do
    file = File.open(fixture_file("empty.html"))
    assert ! Paperclip::MediaTypeSpoofDetector.using(file, "empty.html", "").spoofed?
  end
end
