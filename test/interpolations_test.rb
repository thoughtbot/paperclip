require './test/helper'

class InterpolationsTest < Test::Unit::TestCase
  should "return all methods but the infrastructure when sent #all" do
    methods = Paperclip::Interpolations.all
    assert ! methods.include?(:[])
    assert ! methods.include?(:[]=)
    assert ! methods.include?(:all)
    methods.each do |m|
      assert Paperclip::Interpolations.respond_to?(m)
    end
  end

  should "return the Rails.root" do
    assert_equal Rails.root, Paperclip::Interpolations.rails_root(:attachment, :style)
  end

  should "return the Rails.env" do
    assert_equal Rails.env, Paperclip::Interpolations.rails_env(:attachment, :style)
  end

  should "return the class of the Interpolations module when called with no params" do
    assert_equal Module, Paperclip::Interpolations.class
  end

  should "return the class of the instance" do
    attachment = mock
    attachment.expects(:instance).returns(attachment)
    attachment.expects(:class).returns("Thing")
    assert_equal "things", Paperclip::Interpolations.class(attachment, :style)
  end

  should "return the basename of the file" do
    attachment = mock
    attachment.expects(:original_filename).returns("one.jpg").times(2)
    assert_equal "one", Paperclip::Interpolations.basename(attachment, :style)
  end

  should "return the extension of the file" do
    attachment = mock
    attachment.expects(:original_filename).returns("one.jpg")
    attachment.expects(:styles).returns({})
    assert_equal "jpg", Paperclip::Interpolations.extension(attachment, :style)
  end

  should "return the extension of the file as the format if defined in the style" do
    attachment = mock
    attachment.expects(:original_filename).never
    attachment.expects(:styles).returns({:style => {:format => "png"}})
    assert_equal "png", Paperclip::Interpolations.extension(attachment, :style)
  end

  should "return the id of the attachment" do
    attachment = mock
    attachment.expects(:id).returns(23)
    attachment.expects(:instance).returns(attachment)
    assert_equal 23, Paperclip::Interpolations.id(attachment, :style)
  end

  should "return the partitioned id of the attachment" do
    attachment = mock
    attachment.expects(:id).returns(23)
    attachment.expects(:instance).returns(attachment)
    assert_equal "000/000/023", Paperclip::Interpolations.id_partition(attachment, :style)
  end

  should "return the name of the attachment" do
    attachment = mock
    attachment.expects(:name).returns("file")
    assert_equal "files", Paperclip::Interpolations.attachment(attachment, :style)
  end

  should "return the style" do
    assert_equal :style, Paperclip::Interpolations.style(:attachment, :style)
  end

  should "return the default style" do
    attachment = mock
    attachment.expects(:default_style).returns(:default_style)
    assert_equal :default_style, Paperclip::Interpolations.style(attachment, nil)
  end

  should "reinterpolate :url" do
    attachment = mock
    attachment.expects(:url).with(:style, false).returns("1234")
    assert_equal "1234", Paperclip::Interpolations.url(attachment, :style)
  end

  should "raise if infinite loop detcted reinterpolating :url" do
    attachment = Object.new
    class << attachment
      def url(*args)
        Paperclip::Interpolations.url(self, :style)
      end
    end
    assert_raises(Paperclip::InfiniteInterpolationError){ Paperclip::Interpolations.url(attachment, :style) }
  end

  should "return the filename as basename.extension" do
    attachment = mock
    attachment.expects(:styles).returns({})
    attachment.expects(:original_filename).returns("one.jpg").times(3)
    assert_equal "one.jpg", Paperclip::Interpolations.filename(attachment, :style)
  end

  should "return the filename as basename.extension when format supplied" do
    attachment = mock
    attachment.expects(:styles).returns({:style => {:format => :png}})
    attachment.expects(:original_filename).returns("one.jpg").times(2)
    assert_equal "one.png", Paperclip::Interpolations.filename(attachment, :style)
  end

  should "return the timestamp" do
    now = Time.now
    zone = 'UTC'
    attachment = mock
    attachment.expects(:instance_read).with(:updated_at).returns(now)
    attachment.expects(:time_zone).returns(zone)
    assert_equal now.in_time_zone(zone).to_s, Paperclip::Interpolations.timestamp(attachment, :style)
  end

  should "return updated_at" do
    attachment = mock
    seconds_since_epoch = 1234567890
    attachment.expects(:updated_at).returns(seconds_since_epoch)
    assert_equal seconds_since_epoch, Paperclip::Interpolations.updated_at(attachment, :style)
  end

  should "return hash" do
    attachment = mock
    fake_hash = "a_wicked_secure_hash"
    attachment.expects(:hash).returns(fake_hash)
    assert_equal fake_hash, Paperclip::Interpolations.hash(attachment, :style)
  end

  should "call all expected interpolations with the given arguments" do
    Paperclip::Interpolations.expects(:id).with(:attachment, :style).returns(1234)
    Paperclip::Interpolations.expects(:attachment).with(:attachment, :style).returns("attachments")
    Paperclip::Interpolations.expects(:notreal).never
    value = Paperclip::Interpolations.interpolate(":notreal/:id/:attachment", :attachment, :style)
    assert_equal ":notreal/1234/attachments", value
  end
end
