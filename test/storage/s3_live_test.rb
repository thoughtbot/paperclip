require './test/helper'
require 'aws/s3'

unless ENV["S3_TEST_BUCKET"].blank?
  class S3LiveTest < Test::Unit::TestCase

    context "Generating an expiring url on a nonexistant attachment" do
      setup do
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_TEST_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => File.new(fixture_file("s3.yml"))
    
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
                      :bucket => ENV["S3_TEST_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => File.new(fixture_file("s3.yml"))

        Dummy.delete_all
        @dummy = Dummy.new
      end

      teardown { @dummy.destroy }
      
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
          :bucket => ENV["S3_TEST_BUCKET"],
          :s3_credentials => File.new(fixture_file("s3.yml"))
    
        Dummy.delete_all
        @dummy = Dummy.new
        @dummy.avatar = File.new(fixture_file('spaced file.png'), 'rb')
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

    context "An attachment that uses S3 for storage and has a question mark in file name" do
      context "public or private permissions" do
        setup do
          rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                        :storage => :s3,
                        :bucket => ENV["S3_TEST_BUCKET"],
                        :s3_credentials => File.new(fixture_file("s3.yml"))

          Dummy.delete_all
          @dummy = Dummy.new
          @dummy_file = File.new(fixture_file('question?mark.png'), 'rb')
          @dummy.avatar = @dummy_file
          @dummy.save
        end
        
        teardown { @dummy.destroy }
        
        should "pre-escapes so paths are correct and hashes can be generated" do
          assert_match /.+\/question%3Fmark\.png/, @dummy.avatar.path
        end
        
        should "return an escaped version for url" do
          assert_match /.+\/question%253Fmark\.png/, @dummy.avatar.url
        end

        should "be accessible with an expiring url" do
          # s3 always returns a 403 on an authenticated HEAD request,
          # so we just do a GET and check for equivalence.
          png = `curl -Gs "#{@dummy.avatar.expiring_url}"`
          assert_equal File.read(@dummy_file), png
        end
      end
      
      context "public permissions" do
        setup do
          rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                        :storage => :s3,
                        :bucket => ENV["S3_TEST_BUCKET"],
                        :s3_credentials => File.new(fixture_file("s3.yml"))

          Dummy.delete_all
          @dummy = Dummy.new
          @dummy.avatar = File.new(fixture_file('question?mark.png'), 'rb')
          @dummy.save
        end

        teardown { @dummy.destroy }

        should "be accessible via public url" do
          assert_match /200 OK/, `curl -Is "#{@dummy.avatar.url}"`
        end
        
        should "be destroyable" do
          url = @dummy.avatar.url
          @dummy.destroy
          assert_match /404 Not Found/, `curl -Is "#{url}"`
        end
      end
      
      context "private permissions" do
        setup do
          rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                        :storage => :s3,
                        :bucket => ENV["S3_TEST_BUCKET"],
                        :s3_credentials => File.new(fixture_file("s3.yml")),
                        :s3_permissions => :private

          Dummy.delete_all
          @dummy = Dummy.new
          @dummy_file = File.new(fixture_file('question?mark.png'), 'rb')
          @dummy.avatar = @dummy_file
          @dummy.save
        end

        teardown { @dummy.destroy }

        should "not be accessible via public url" do
          assert_match /403 Forbidden/, `curl -Is "#{@dummy.avatar.url}"`
        end

        should "be destroyable" do
          url = @dummy.avatar.expiring_url

          # Have to use GET here because s3 returns 403 for all expiring_url HEAD requests.
          cmd = "curl -Gs '#{url}'"

          # make sure it's there first
          assert_equal File.read(@dummy_file), `#{cmd}`
          
          @dummy.destroy
          assert_match /The specified key does not exist/, `#{cmd}`
        end
      end
    end
  end
end
