require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'right_aws'

require File.join(File.dirname(__FILE__), '..', 'lib', 'paperclip', 'geometry.rb')

class S3Test < Test::Unit::TestCase
  context "An attachment with S3 storage" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }

      @s3_mock     = stub
      @bucket_mock = stub
      RightAws::S3.expects(:new).
        with("12345", "54321", {}).
        returns(@s3_mock)
      @s3_mock.expects(:bucket).with("testing", true, "public-read").returns(@bucket_mock)
    end

    should "be extended by the S3 module" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::S3)
    end

    should "not be extended by the Filesystem module" do
      assert ! Dummy.new.avatar.is_a?(Paperclip::Storage::Filesystem)
    end

    context "when assigned" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'))
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      should "still return a Tempfile when sent #to_io" do
        assert_equal Tempfile, @dummy.avatar.to_io.class
      end

      context "and saved" do
        setup do
          @key_mock = stub
          @bucket_mock.expects(:key).returns(@key_mock)
          @key_mock.expects(:data=)
          @key_mock.expects(:put)
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end
    end
  end

  unless ENV["S3_TEST_BUCKET"].blank?
    context "Using S3 for real, an attachment with S3 storage" do
      setup do
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_TEST_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => File.new(File.join(File.dirname(__FILE__), "s3.yml"))

        Dummy.delete_all
        @dummy = Dummy.new
      end

      should "be extended by the S3 module" do
        assert Dummy.new.avatar.is_a?(Paperclip::Storage::S3)
      end

      context "when assigned" do
        setup do
          @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'))
          @dummy.avatar = @file
        end

        should "still return a Tempfile when sent #to_io" do
          assert_equal Tempfile, @dummy.avatar.to_io.class
        end

        context "and saved" do
          setup do
            @dummy.save
          end

          should "be on S3" do
            assert true
          end
        end
      end
    end
  end
end
