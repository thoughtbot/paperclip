require './test/helper'
require 'aws'

unless ENV["S3_BUCKET"].blank?
  class S3LiveTest < Test::Unit::TestCase

    context "Generating an expiring url on a nonexistant attachment" do
      setup do
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => File.new(File.join(File.dirname(__FILE__), "..", "fixtures", "s3.yml"))

        @dummy = Dummy.new
      end
      should "return nil" do
        assert_nil @dummy.avatar.expiring_url
      end
    end

    context "Using S3 for real, an attachment with S3 storage" do
      setup do
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => File.new(File.join(File.dirname(__FILE__), "..", "fixtures", "s3.yml"))

        Dummy.delete_all
        @dummy = Dummy.new
      end

      should "be extended by the S3 module" do
        assert Dummy.new.avatar.is_a?(Paperclip::Storage::S3)
      end

      context "when assigned" do
        setup do
          @file = File.new(fixture_file('5k.png'), 'rb')
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
          :bucket => ENV["S3_BUCKET"],
          :s3_credentials => File.new(File.join(File.dirname(__FILE__), "..", "fixtures", "s3.yml"))

        Dummy.delete_all
        @dummy = Dummy.new
        @dummy.avatar = File.new(fixture_file('spaced file.png'), 'rb')
        @dummy.save
      end

      should "return an unescaped version for path" do
        assert_match /.+\/spaced file\.png/, @dummy.avatar.path
      end

      should "return an escaped version for url" do
        assert_match /.+\/spaced%20file\.png/, @dummy.avatar.url
      end

      should "be accessible" do
        assert_success_response @dummy.avatar.url
      end

      should "be destoryable" do
        url = @dummy.avatar.url
        @dummy.destroy
        assert_not_found_response url
      end
    end

    context "An attachment that uses S3 for storage and has a question mark in file name" do
      setup do
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_BUCKET"],
                      :s3_credentials => File.new(File.join(File.dirname(__FILE__), "..", "fixtures", "s3.yml"))

        Dummy.delete_all
        @dummy = Dummy.new
        @dummy.avatar = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', 'question?mark.png'), 'rb')
        @dummy.save
      end

      should "return an unescaped version for path" do
        assert_match /.+\/question\?mark\.png/, @dummy.avatar.path
      end

      should "return an escaped version for url" do
        assert_match /.+\/question%3Fmark\.png/, @dummy.avatar.url
      end

      should "be accessible" do
        assert_success_response @dummy.avatar.url
      end

      should "be accessible with an expiring url" do
        assert_success_response @dummy.avatar.expiring_url
      end

      should "be destroyable" do
        url = @dummy.avatar.url
        @dummy.destroy
        assert_not_found_response url
      end
    end
  end
end
