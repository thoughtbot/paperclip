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
    attachment.expects(:styles).twice.returns({:style => {:format => "png"}})

    [:style, 'style'].each do |style|
      assert_equal "png", Paperclip::Interpolations.extension(attachment, style)
    end
  end

  should "return the extension of the file based on the content type" do
    attachment = mock
    attachment.expects(:content_type).returns('image/jpeg')
    interpolations = Paperclip::Interpolations
    interpolations.expects(:extension).returns('random')
    assert_equal "jpeg", interpolations.content_type_extension(attachment, :style)
  end

  should "return the original extension of the file if it matches a content type extension" do
    attachment = mock
    attachment.expects(:content_type).returns('image/jpeg')
    interpolations = Paperclip::Interpolations
    interpolations.expects(:extension).returns('jpe')
    assert_equal "jpe", interpolations.content_type_extension(attachment, :style)
  end

  should "return the latter half of the content type of the extension if no match found" do
    attachment = mock
    attachment.expects(:content_type).at_least_once().returns('not/found')
    interpolations = Paperclip::Interpolations
    interpolations.expects(:extension).returns('random')
    assert_equal "found", interpolations.content_type_extension(attachment, :style)
  end

  should "be able to handle numeric style names" do
    attachment = mock(
      :styles => {:"4" => {:format => :expected_extension}}
    )
    assert_equal :expected_extension, Paperclip::Interpolations.extension(attachment, 4)
  end

  should "return the #to_param of the attachment" do
    attachment = mock
    attachment.expects(:to_param).returns("23-awesome")
    attachment.expects(:instance).returns(attachment)
    assert_equal "23-awesome", Paperclip::Interpolations.param(attachment, :style)
  end

  should "return the id of the attachment" do
    attachment = mock
    attachment.expects(:id).returns(23)
    attachment.expects(:instance).returns(attachment)
    assert_equal 23, Paperclip::Interpolations.id(attachment, :style)
  end

  should "return nil for attachments to new records" do
    attachment = mock
    attachment.expects(:id).returns(nil)
    attachment.expects(:instance).returns(attachment)
    assert_nil Paperclip::Interpolations.id(attachment, :style)
  end

  should "return the partitioned id of the attachment when the id is an integer" do
    attachment = mock
    attachment.expects(:id).returns(23)
    attachment.expects(:instance).returns(attachment)
    assert_equal "000/000/023", Paperclip::Interpolations.id_partition(attachment, :style)
  end

  should "return the partitioned id of the attachment when the id is a string" do
    attachment = mock
    attachment.expects(:id).returns("32fnj23oio2f")
    attachment.expects(:instance).returns(attachment)
    assert_equal "32f/nj2/3oi", Paperclip::Interpolations.id_partition(attachment, :style)
  end

  should "return nil for the partitioned id of an attachment to a new record (when the id is nil)" do
    attachment = mock
    attachment.expects(:id).returns(nil)
    attachment.expects(:instance).returns(attachment)
    assert_nil Paperclip::Interpolations.id_partition(attachment, :style)
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
    attachment.expects(:url).with(:style, :timestamp => false, :escape => false).returns("1234")
    assert_equal "1234", Paperclip::Interpolations.url(attachment, :style)
  end

  should "raise if infinite loop detcted reinterpolating :url" do
    attachment = Object.new
    class << attachment
      def url(*args)
        Paperclip::Interpolations.url(self, :style)
      end
    end
    assert_raises(Paperclip::Errors::InfiniteInterpolationError){ Paperclip::Interpolations.url(attachment, :style) }
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

  should "return the filename as basename when extension is blank" do
    attachment = mock
    attachment.stubs(:styles).returns({})
    attachment.stubs(:original_filename).returns("one")
    assert_equal "one", Paperclip::Interpolations.filename(attachment, :style)
  end
  
  should "return the basename when the extension contains regexp special characters" do
    attachment = mock
    attachment.stubs(:styles).returns({})
    attachment.stubs(:original_filename).returns("one.ab)")
    assert_equal "one", Paperclip::Interpolations.basename(attachment, :style)
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

  should "return attachment's hash when passing both arguments" do
    attachment = mock
    fake_hash = "a_wicked_secure_hash"
    attachment.expects(:hash_key).returns(fake_hash)
    assert_equal fake_hash, Paperclip::Interpolations.hash(attachment, :style)
  end

  should "return Object#hash when passing no argument" do
    attachment = mock
    fake_hash = "a_wicked_secure_hash"
    attachment.expects(:hash_key).never.returns(fake_hash)
    assert_not_equal fake_hash, Paperclip::Interpolations.hash
  end

  should "call all expected interpolations with the given arguments" do
    Paperclip::Interpolations.expects(:id).with(:attachment, :style).returns(1234)
    Paperclip::Interpolations.expects(:attachment).with(:attachment, :style).returns("attachments")
    Paperclip::Interpolations.expects(:notreal).never
    value = Paperclip::Interpolations.interpolate(":notreal/:id/:attachment", :attachment, :style)
    assert_equal ":notreal/1234/attachments", value
  end
end
