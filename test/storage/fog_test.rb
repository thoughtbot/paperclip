require './test/helper'
require 'fog'

class FogTest < Test::Unit::TestCase
  context "" do
    setup { Fog.mock! }

    context "with credentials provided in a path string" do
      setup do
        rebuild_model :styles => { :medium => "300x300>", :thumb => "100x100>" },
                      :storage => :fog,
                      :url => '/:attachment/:filename',
                      :fog_directory => "paperclip",
                      :fog_credentials => fixture_file('fog.yml')
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      should "have the proper information loading credentials from a file" do
        assert_equal @dummy.avatar.fog_credentials[:provider], 'AWS'
      end
    end

    context "with credentials provided in a File object" do
      setup do
        rebuild_model :styles => { :medium => "300x300>", :thumb => "100x100>" },
                      :storage => :fog,
                      :url => '/:attachment/:filename',
                      :fog_directory => "paperclip",
                      :fog_credentials => File.open(fixture_file('fog.yml'))
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      should "have the proper information loading credentials from a file" do
        assert_equal @dummy.avatar.fog_credentials[:provider], 'AWS'
      end
    end

    context "with default values for path and url" do
      setup do
        rebuild_model :styles => { :medium => "300x300>", :thumb => "100x100>" },
                      :storage => :fog,
                      :url => '/:attachment/:filename',
                      :fog_directory => "paperclip",
                      :fog_credentials => {
                        :provider => 'AWS',
                        :aws_access_key_id => 'AWS_ID',
                        :aws_secret_access_key => 'AWS_SECRET'
                      }
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      should "be able to interpolate the path without blowing up" do
        assert_equal File.expand_path(File.join(File.dirname(__FILE__), "../../tmp/public/avatars/5k.png")),
                     @dummy.avatar.path
      end
    end
    
    context "with no path or url given and using defaults" do
      setup do
        rebuild_model :styles => { :medium => "300x300>", :thumb => "100x100>" },
                      :storage => :fog,
                      :fog_directory => "paperclip",
                      :fog_credentials => {
                        :provider => 'AWS',
                        :aws_access_key_id => 'AWS_ID',
                        :aws_secret_access_key => 'AWS_SECRET'
                      }
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.id = 1
        @dummy.avatar = @file
      end
      
      teardown { @file.close }
      
      should "have correct path and url from interpolated defaults" do
        assert_equal "dummies/avatars/000/000/001/original/5k.png", @dummy.avatar.path
      end
    end

    setup do
      @fog_directory = 'papercliptests'

      @credentials = {
        :provider               => 'AWS',
        :aws_access_key_id      => 'ID',
        :aws_secret_access_key  => 'SECRET'
      }

      @connection = Fog::Storage.new(@credentials)
      @connection.directories.create(
        :key => @fog_directory
      )

      @options = {
        :fog_directory    => @fog_directory,
        :fog_credentials  => @credentials,
        :fog_host         => nil,
        :fog_file         => {:cache_control => 1234},
        :path             => ":attachment/:basename.:extension",
        :storage          => :fog
      }

      rebuild_model(@options)
    end

    should "be extended by the Fog module" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::Fog)
    end

    context "when assigned" do
      setup do
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown do
        @file.close
        directory = @connection.directories.new(:key => @fog_directory)
        directory.files.each {|file| file.destroy}
        directory.destroy
      end

      should "be rewinded after flush_writes" do
        @dummy.avatar.instance_eval "def after_flush_writes; end"

        files = @dummy.avatar.queued_for_write.values
        @dummy.save
        assert files.none?(&:eof?), "Expect all the files to be rewinded."
      end

      should "be removed after after_flush_writes" do
        paths = @dummy.avatar.queued_for_write.values.map(&:path)
        @dummy.save
        assert paths.none?{ |path| File.exists?(path) },
          "Expect all the files to be deleted."
      end

      should 'be able to be copied to a local file' do
        @dummy.save
        tempfile = Tempfile.new("known_location")
        tempfile.binmode
        @dummy.avatar.copy_to_local_file(:original, tempfile.path)
        tempfile.rewind
        assert_equal @connection.directories.get(@fog_directory).files.get(@dummy.avatar.path).body,
                     tempfile.read
        tempfile.close
      end

      should "pass the content type to the Fog::Storage::AWS::Files instance" do
        Fog::Storage::AWS::Files.any_instance.expects(:create).with do |hash|
          hash[:content_type]
        end
        @dummy.save
      end

      context "without a bucket" do
        setup do
          @connection.directories.get(@fog_directory).destroy
        end

        should "create the bucket" do
          assert @dummy.save
          assert @connection.directories.get(@fog_directory)
        end
      end

      context "with a bucket" do
        should "succeed" do
          assert @dummy.save
        end
      end

      context "without a fog_host" do
        setup do
          rebuild_model(@options.merge(:fog_host => nil))
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should "provide a public url" do
          assert !@dummy.avatar.url.nil?
        end
      end

      context "with a fog_host" do
        setup do
          rebuild_model(@options.merge(:fog_host => 'http://example.com'))
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should "provide a public url" do
          assert @dummy.avatar.url =~ /^http:\/\/example\.com\/avatars\/stringio\.txt\?\d*$/
        end
      end

      context "with a fog_host that includes a wildcard placeholder" do
        setup do
          rebuild_model(
            :fog_directory    => @fog_directory,
            :fog_credentials  => @credentials,
            :fog_host         => 'http://img%d.example.com',
            :path             => ":attachment/:basename.:extension",
            :storage          => :fog
          )
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should "provide a public url" do
          assert @dummy.avatar.url =~ /^http:\/\/img[0123]\.example\.com\/avatars\/stringio\.txt\?\d*$/
        end
      end

      context "with fog_public set to false" do
        setup do
          rebuild_model(@options.merge(:fog_public => false))
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should 'set the @fog_public instance variable to false' do
          assert_equal false, @dummy.avatar.instance_variable_get('@options')[:fog_public]
          assert_equal false, @dummy.avatar.fog_public
        end
      end

      context "with styles set and fog_public set to false" do
        setup do
          rebuild_model(@options.merge(:fog_public => false, :styles => { :medium => "300x300>", :thumb => "100x100>" }))
          @file = File.new(fixture_file('5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.avatar = @file
          @dummy.save
        end

        should 'set the @fog_public for a particular style to false' do
          assert_equal false, @dummy.avatar.instance_variable_get('@options')[:fog_public]
          assert_equal false, @dummy.avatar.fog_public(:thumb)
        end
      end

      context "with styles set and fog_public set per-style" do
        setup do
          rebuild_model(@options.merge(:fog_public => { :medium => false, :thumb => true}, :styles => { :medium => "300x300>", :thumb => "100x100>" }))
          @file = File.new(fixture_file('5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.avatar = @file
          @dummy.save
        end

        should 'set the fog_public for a particular style to correct value' do
          assert_equal false, @dummy.avatar.fog_public(:medium)
          assert_equal true, @dummy.avatar.fog_public(:thumb)
        end
      end

      context "with fog_public not set" do
        setup do
          rebuild_model(@options)
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should "default fog_public to true" do
          assert_equal true, @dummy.avatar.fog_public
        end
      end

      context "with a valid bucket name for a subdomain" do
        should "provide an url in subdomain style" do
          assert_match @dummy.avatar.url, /^https:\/\/papercliptests.s3.amazonaws.com\/avatars\/5k.png/
        end

        should "provide an url that expires in subdomain style" do
          assert_match /^http:\/\/papercliptests.s3.amazonaws.com\/avatars\/5k.png\?AWSAccessKeyId=.+$/, @dummy.avatar.expiring_url
        end
      end

      context "with an invalid bucket name for a subdomain" do
        setup do
          rebuild_model(@options.merge(:fog_directory => "this_is_invalid"))
          @dummy = Dummy.new
          @dummy.avatar = @file
          @dummy.save
        end

        should "not match the bucket-subdomain restrictions" do
          invalid_subdomains = %w(this_is_invalid in iamareallylongbucketnameiamareallylongbucketnameiamareallylongbu invalid- inval..id inval-.id inval.-id -invalid 192.168.10.2)
          invalid_subdomains.each do |name|
            assert_no_match Paperclip::Storage::Fog::AWS_BUCKET_SUBDOMAIN_RESTRICTON_REGEX, name
          end
        end

        should "provide an url in folder style" do
          assert_match /^https:\/\/s3.amazonaws.com\/this_is_invalid\/avatars\/5k.png\?\d*$/, @dummy.avatar.url
        end

        should "provide a url that expires in folder style" do
          assert_match /^http:\/\/s3.amazonaws.com\/this_is_invalid\/avatars\/5k.png\?AWSAccessKeyId=.+$/, @dummy.avatar.expiring_url
        end

      end

      context "with a proc for a bucket name evaluating a model method" do
        setup do
          @dynamic_fog_directory = 'dynamicpaperclip'
          rebuild_model(@options.merge(:fog_directory => lambda { |attachment| attachment.instance.bucket_name }))
          @dummy = Dummy.new
          @dummy.stubs(:bucket_name).returns(@dynamic_fog_directory)
          @dummy.avatar = @file
          @dummy.save
        end

        should "have created the bucket" do
          assert @connection.directories.get(@dynamic_fog_directory).inspect
        end

      end

      context "with a proc for the fog_host evaluating a model method" do
        setup do
          rebuild_model(@options.merge(:fog_host => lambda { |attachment| attachment.instance.fog_host }))
          @dummy = Dummy.new
          @dummy.stubs(:fog_host).returns('http://dynamicfoghost.com')
          @dummy.avatar = @file
          @dummy.save
        end

        should "provide a public url" do
          assert_match /http:\/\/dynamicfoghost\.com/, @dummy.avatar.url
        end

      end

      context "with a custom fog_host" do
        setup do
          rebuild_model(@options.merge(:fog_host => "http://dynamicfoghost.com"))
          @dummy = Dummy.new
          @dummy.avatar = @file
          @dummy.save
        end

        should "provide a public url" do
          assert_match /http:\/\/dynamicfoghost\.com/, @dummy.avatar.url
        end

        should "provide an expiring url" do
          assert_match /http:\/\/dynamicfoghost\.com/, @dummy.avatar.expiring_url
        end

        context "with an invalid bucket name for a subdomain" do
          setup do
            rebuild_model(@options.merge({:fog_directory => "this_is_invalid", :fog_host => "http://dynamicfoghost.com"}))
            @dummy = Dummy.new
            @dummy.avatar = @file
            @dummy.save
          end

          should "provide an expiring url" do
            assert_match /http:\/\/dynamicfoghost\.com/, @dummy.avatar.expiring_url
          end
        end

      end

      context "with a proc for the fog_credentials evaluating a model method" do
        setup do
          @dynamic_fog_credentials = {
            :provider               => 'AWS',
            :aws_access_key_id      => 'DYNAMIC_ID',
            :aws_secret_access_key  => 'DYNAMIC_SECRET'
          }
          rebuild_model(@options.merge(:fog_credentials => lambda { |attachment| attachment.instance.fog_credentials }))
          @dummy = Dummy.new
          @dummy.stubs(:fog_credentials).returns(@dynamic_fog_credentials)
          @dummy.avatar = @file
          @dummy.save
        end

        should "provide a public url" do
          assert_equal @dummy.avatar.fog_credentials, @dynamic_fog_credentials
        end
      end
    end

  end

  context "when using local storage" do
    setup do
      Fog.unmock!
      rebuild_model :styles => { :medium => "300x300>", :thumb => "100x100>" },
                    :storage => :fog,
                    :url => '/:attachment/:filename',
                    :fog_directory => "paperclip",
                    :fog_credentials => { :provider => :local, :local_root => "." },
                    :fog_host => 'localhost'

      @file = File.new(fixture_file('5k.png'), 'rb')
      @dummy = Dummy.new
      @dummy.avatar = @file
    end

    teardown do
      @file.close
      Fog.mock!
    end

    should "return the public url in place of the expiring url" do
      assert_match @dummy.avatar.public_url, @dummy.avatar.expiring_url
    end
  end
end
