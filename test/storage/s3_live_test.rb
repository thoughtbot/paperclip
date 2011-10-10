require './test/helper'
require 'aws/s3'

unless ENV["S3_TEST_BUCKET"].blank?
  class S3LiveTest < Test::Unit::TestCase
    context "Using S3 for real, an attachment with S3 storage" do
      setup do
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_TEST_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => File.new(File.join(File.dirname(__FILE__), "..", "s3.yml"))

        Dummy.delete_all
        @dummy = Dummy.new
      end

      should "be extended by the S3 module" do
        assert Dummy.new.avatar.is_a?(Paperclip::Storage::S3)
      end

      context "when assigned" do
        setup do
          @file = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', '5k.png'), 'rb')
          @dummy.avatar = @file
        end

        teardown do
          @file.close
          @dummy.destroy
        end

        should "still return a Tempfile when sent #to_file" do
          assert_equal Paperclip::Tempfile, @dummy.avatar.to_file.class
        end

        context "and saved" do
          setup do
            @dummy.save
          end

          should "be on S3" do
            assert true
          end

          should "generate a tempfile with the right name" do
            file = @dummy.avatar.to_file
            assert_match /^original.*\.png$/, File.basename(file.path)
          end
        end
      end
    end

    context "An attachment that uses S3 for storage and has spaces in file name" do
      setup do
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_TEST_BUCKET"],
                      :s3_credentials => File.new(File.join(File.dirname(__FILE__), "..", "s3.yml"))

        Dummy.delete_all
        @dummy = Dummy.new
        @dummy.avatar = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', 'spaced file.png'), 'rb')
        @dummy.save
      end

      teardown { @dummy.destroy }

      should "return an unescaped version for path" do
        assert_match /.+\/spaced file\.png/, @dummy.avatar.path
      end

      should "return an escaped version for url" do
        assert_match /.+\/spaced%20file\.png/, @dummy.avatar.url
      end

      should "be accessible" do
        assert_match /200 OK/, `curl -I #{@dummy.avatar.url}`
      end

      should "be destoryable" do
        url = @dummy.avatar.url
        @dummy.destroy
        assert_match /404 Not Found/, `curl -I #{url}`
      end
    end
  end
end
