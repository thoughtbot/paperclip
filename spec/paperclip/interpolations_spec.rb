require 'spec_helper'

describe Paperclip::Interpolations do
  it "returns all methods but the infrastructure when sent #all" do
    methods = Paperclip::Interpolations.all
    assert ! methods.include?(:[])
    assert ! methods.include?(:[]=)
    assert ! methods.include?(:all)
    methods.each do |m|
      assert Paperclip::Interpolations.respond_to?(m)
    end
  end

  it "returns the Rails.root" do
    assert_equal Rails.root, Paperclip::Interpolations.rails_root(:attachment, :style)
  end

  it "returns the Rails.env" do
    assert_equal Rails.env, Paperclip::Interpolations.rails_env(:attachment, :style)
  end

  it "returns the class of the Interpolations module when called with no params" do
    assert_equal Module, Paperclip::Interpolations.class
  end

  it "returns the class of the instance" do
    class Thing ; end
    attachment = mock
    expect(attachment).to receive(:instance).and_return(attachment)
    expect(attachment).to receive(:class).and_return(Thing)
    assert_equal "things", Paperclip::Interpolations.class(attachment, :style)
  end

  it "returns the basename of the file" do
    attachment = mock
    expect(attachment).to receive(:original_filename).and_return("one.jpg").times(1)
    assert_equal "one", Paperclip::Interpolations.basename(attachment, :style)
  end

  it "returns the extension of the file" do
    attachment = mock
    expect(attachment).to receive(:original_filename).and_return("one.jpg")
    expect(attachment).to receive(:styles).and_return({})
    assert_equal "jpg", Paperclip::Interpolations.extension(attachment, :style)
  end

  it "returns the extension of the file as the format if defined in the style" do
    attachment = mock
    expect(attachment).to_not receive(:original_filename)
    expect(attachment).to receive(:styles).at_least(2).times.and_return({style: {format: "png"}})

    [:style, 'style'].each do |style|
      assert_equal "png", Paperclip::Interpolations.extension(attachment, style)
    end
  end

  it "returns the extension of the file based on the content type" do
    attachment = mock
    expect(attachment).to receive(:content_type).and_return('image/png')
    expect(attachment).to receive(:styles).and_return({})
    interpolations = Paperclip::Interpolations
    expect(interpolations).to receive(:extension).and_return('random')
    assert_equal "png", interpolations.content_type_extension(attachment, :style)
  end

  it "returns the original extension of the file if it matches a content type extension" do
    attachment = mock
    expect(attachment).to receive(:content_type).and_return('image/jpeg')
    expect(attachment).to receive(:styles).and_return({})
    interpolations = Paperclip::Interpolations
    expect(interpolations).to receive(:extension).and_return('jpe')
    assert_equal "jpe", interpolations.content_type_extension(attachment, :style)
  end

  it "returns the extension of the file with a dot" do
    attachment = mock
    expect(attachment).to receive(:original_filename).and_return("one.jpg")
    expect(attachment).to receive(:styles).and_return({})
    assert_equal ".jpg", Paperclip::Interpolations.dotextension(attachment, :style)
  end

  it "returns the extension of the file without a dot if the extension is empty" do
    attachment = mock
    expect(attachment).to receive(:original_filename).and_return("one")
    expect(attachment).to receive(:styles).and_return({})
    assert_equal "", Paperclip::Interpolations.dotextension(attachment, :style)
  end

  it "returns the latter half of the content type of the extension if no match found" do
    attachment = mock
    allow(attachment).to receive(:content_type).at_least(1).times.and_return('not/found')
    allow(attachment).to receive(:styles).and_return({})
    interpolations = Paperclip::Interpolations
    expect(interpolations).to receive(:extension).and_return('random')
    assert_equal "found", interpolations.content_type_extension(attachment, :style)
  end

  it "returns the format if defined in the style, ignoring the content type" do
    attachment = mock
    expect(attachment).to receive(:content_type).and_return('image/jpeg')
    expect(attachment).to receive(:styles).and_return({style: {format: "png"}})
    interpolations = Paperclip::Interpolations
    expect(interpolations).to receive(:extension).and_return('random')
    assert_equal "png", interpolations.content_type_extension(attachment, :style)
  end

  it "is able to handle numeric style names" do
    attachment = mock(
      styles: {:"4" => {format: :expected_extension}}
    )
    assert_equal :expected_extension, Paperclip::Interpolations.extension(attachment, 4)
  end

  it "returns the #to_param of the attachment" do
    attachment = mock
    expect(attachment).to receive(:to_param).and_return("23-awesome")
    expect(attachment).to receive(:instance).and_return(attachment)
    assert_equal "23-awesome", Paperclip::Interpolations.param(attachment, :style)
  end

  it "returns the id of the attachment" do
    attachment = mock
    expect(attachment).to receive(:id).and_return(23)
    expect(attachment).to receive(:instance).and_return(attachment)
    assert_equal 23, Paperclip::Interpolations.id(attachment, :style)
  end

  it "returns nil for attachments to new records" do
    attachment = mock
    expect(attachment).to receive(:id).and_return(nil)
    expect(attachment).to receive(:instance).and_return(attachment)
    assert_nil Paperclip::Interpolations.id(attachment, :style)
  end

  it "returns the partitioned id of the attachment when the id is an integer" do
    attachment = mock
    expect(attachment).to receive(:id).and_return(23)
    expect(attachment).to receive(:instance).and_return(attachment)
    assert_equal "000/000/023", Paperclip::Interpolations.id_partition(attachment, :style)
  end

  it "returns the partitioned id when the id is above 999_999_999" do
    attachment = mock
    expect(attachment).to receive(:id).and_return(Paperclip::Interpolations::ID_PARTITION_LIMIT)
    expect(attachment).to receive(:instance).and_return(attachment)
    assert_equal "001/000/000/000",
      Paperclip::Interpolations.id_partition(attachment, :style)
  end

  it "returns the partitioned id of the attachment when the id is a string" do
    attachment = mock
    expect(attachment).to receive(:id).and_return("32fnj23oio2f")
    expect(attachment).to receive(:instance).and_return(attachment)
    assert_equal "32f/nj2/3oi", Paperclip::Interpolations.id_partition(attachment, :style)
  end

  it "returns nil for the partitioned id of an attachment to a new record (when the id is nil)" do
    attachment = mock
    expect(attachment).to receive(:id).and_return(nil)
    expect(attachment).to receive(:instance).and_return(attachment)
    assert_nil Paperclip::Interpolations.id_partition(attachment, :style)
  end

  it "returns the name of the attachment" do
    attachment = mock
    expect(attachment).to receive(:name).and_return("file")
    assert_equal "files", Paperclip::Interpolations.attachment(attachment, :style)
  end

  it "returns the style" do
    assert_equal :style, Paperclip::Interpolations.style(:attachment, :style)
  end

  it "returns the default style" do
    attachment = mock
    expect(attachment).to receive(:default_style).and_return(:default_style)
    assert_equal :default_style, Paperclip::Interpolations.style(attachment, nil)
  end

  it "reinterpolates :url" do
    attachment = mock
    expect(attachment).to receive(:url).with(:style, timestamp: false, escape: false).and_return("1234")
    assert_equal "1234", Paperclip::Interpolations.url(attachment, :style)
  end

  it "raises if infinite loop detcted reinterpolating :url" do
    attachment = Object.new
    class << attachment
      def url(*args)
        Paperclip::Interpolations.url(self, :style)
      end
    end
    assert_raises(Paperclip::Errors::InfiniteInterpolationError){ Paperclip::Interpolations.url(attachment, :style) }
  end

  it "returns the filename as basename.extension" do
    attachment = mock
    expect(attachment).to receive(:styles).and_return({})
    expect(attachment).to receive(:original_filename).and_return("one.jpg").times(2)
    assert_equal "one.jpg", Paperclip::Interpolations.filename(attachment, :style)
  end

  it "returns the filename as basename.extension when format supplied" do
    attachment = mock
    expect(attachment).to receive(:styles).and_return({style: {format: :png}})
    expect(attachment).to receive(:original_filename).and_return("one.jpg").times(1)
    assert_equal "one.png", Paperclip::Interpolations.filename(attachment, :style)
  end

  it "returns the filename as basename when extension is blank" do
    attachment = mock
    allow(attachment).to receive(:styles).and_return({})
    allow(attachment).to receive(:original_filename).and_return("one")
    assert_equal "one", Paperclip::Interpolations.filename(attachment, :style)
  end

  it "returns the basename when the extension contains regexp special characters" do
    attachment = mock
    allow(attachment).to receive(:styles).and_return({})
    allow(attachment).to receive(:original_filename).and_return("one.ab)")
    assert_equal "one", Paperclip::Interpolations.basename(attachment, :style)
  end

  it "returns the timestamp" do
    now = Time.now
    zone = 'UTC'
    attachment = mock
    expect(attachment).to receive(:instance_read).with(:updated_at).and_return(now)
    expect(attachment).to receive(:time_zone).and_return(zone)
    assert_equal now.in_time_zone(zone).to_s, Paperclip::Interpolations.timestamp(attachment, :style)
  end

  it "returns updated_at" do
    attachment = mock
    seconds_since_epoch = 1234567890
    expect(attachment).to receive(:updated_at).and_return(seconds_since_epoch)
    assert_equal seconds_since_epoch, Paperclip::Interpolations.updated_at(attachment, :style)
  end

  it "returns attachment's hash when passing both arguments" do
    attachment = mock
    fake_hash = "a_wicked_secure_hash"
    expect(attachment).to receive(:hash_key).and_return(fake_hash)
    assert_equal fake_hash, Paperclip::Interpolations.hash(attachment, :style)
  end

  it "returns Object#hash when passing no argument" do
    attachment = mock
    fake_hash = "a_wicked_secure_hash"
    expect(attachment).to_not receive(:hash_key).and_return(fake_hash)
    assert_not_equal fake_hash, Paperclip::Interpolations.hash
  end

  it "calls all expected interpolations with the given arguments" do
    expect(Paperclip::Interpolations).to receive(:id).with(:attachment, :style).and_return(1234)
    expect(Paperclip::Interpolations).to receive(:attachment).with(:attachment, :style).and_return("attachments")
    expect(Paperclip::Interpolations).to_not receive(:notreal)
    value = Paperclip::Interpolations.interpolate(":notreal/:id/:attachment", :attachment, :style)
    assert_equal ":notreal/1234/attachments", value
  end

  it "handles question marks" do
    Paperclip.interpolates :foo? do
      "bar"
    end
    expect(Paperclip::Interpolations).to_not receive(:fool)
    value = Paperclip::Interpolations.interpolate(":fo/:foo?")
    assert_equal ":fo/bar", value
  end
end
