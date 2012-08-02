require './test/helper'
require 'aws'

unless ENV["S3_BUCKET"].blank?
  class S3LiveTest < Test::Unit::TestCase
    context "when assigning an S3 attachment directly to another model" do
      setup do
        @s3_credentials = File.new(fixture_file("s3.yml"))
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => @s3_credentials

        @file = File.new(fixture_file("5k.png"))
      end

      should "not raise any error" do
        @attachment = Dummy.new.avatar
        @attachment.assign(@file)
        @attachment.save

        @attachment2 = Dummy.new.avatar
        @attachment2.assign(@file)
        @attachment2.save
      end

      should "allow assignment from another S3 object" do
        @attachment = Dummy.new.avatar
        @attachment.assign(@file)
        @attachment.save

        @attachment2 = Dummy.new.avatar
        @attachment2.assign(@attachment)
        @attachment2.save
      end

      teardown { [@s3_credentials, @file].each(&:close) }
    end

    context "Generating an expiring url on a nonexistant attachment" do
      setup do
        @s3_credentials = File.new(fixture_file("s3.yml"))
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => @s3_credentials

        @dummy = Dummy.new
      end

      should "return nil" do
        assert_nil @dummy.avatar.expiring_url
      end
    end

    context "Using S3 for real, an attachment with S3 storage" do
      setup do
        @s3_credentials = File.new(fixture_file("s3.yml"))
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => @s3_credentials

        Dummy.delete_all
        @dummy = Dummy.new
      end

      teardown { @s3_credentials.close }

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

    context "An attachment that uses S3 for storage and has spaces in file name" do
      setup do
        @s3_credentials = File.new(fixture_file("s3.yml"))
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
          :storage => :s3,
          :bucket => ENV["S3_BUCKET"],
          :s3_credentials => @s3_credentials

        Dummy.delete_all
        @file = File.new(fixture_file('spaced file.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
        @dummy.save
      end

      teardown { @s3_credentials.close }

      should "return a replaced version for path" do
        assert_match /.+\/spaced_file\.png/, @dummy.avatar.path
      end

      should "return a replaced version for url" do
        assert_match /.+\/spaced_file\.png/, @dummy.avatar.url
      end

      should "be accessible" do
        assert_success_response @dummy.avatar.url
      end

      should "be reprocessable" do
        assert @dummy.avatar.reprocess!
      end

      should "be destroyable" do
        url = @dummy.avatar.url
        @dummy.destroy
        assert_not_found_response url
      end
    end

    context "An attachment that uses S3 for storage and uses AES256 encryption" do
      setup do
        @s3_credentials = File.new(fixture_file("s3.yml"))
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => @s3_credentials,
                      :s3_server_side_encryption => :aes256

        Dummy.delete_all
        @dummy = Dummy.new
      end

      teardown { @s3_credentials.close }

      context "when assigned" do
        setup do
          @file = File.new(fixture_file('5k.png'), 'rb')
          @dummy.avatar = @file
        end

        teardown do
          @file.close
          @dummy.destroy
        end

        context "and saved" do
          setup do
            @dummy.save
          end

          should "be encrypted on S3" do
            assert @dummy.avatar.s3_object.server_side_encryption == :aes256
          end
        end
      end
    end
  end
end
