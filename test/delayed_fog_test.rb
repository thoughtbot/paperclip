require './test/helper'
require 'fog'

Fog.mock!

class DelayedFogTest < Test::Unit::TestCase

  context "" do
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
        :fog_public       => true,
        :fog_file         => {:cache_control => 1234},
        :path             => ":attachment/:basename.:extension",
        :storage          => :delayed_fog
      }
    end
  
    context "filesystem" do
      setup do
        rebuild_model @options.merge(:styles => { :thumbnail => "25x25#"})
        @dummy = Dummy.create!

        @dummy.avatar = File.open(File.join(File.dirname(__FILE__), "fixtures", "5k.png"))
      end

      should "allow file assignment" do
        assert @dummy.save
      end

      should "store the original" do
        @dummy.save
        assert File.exists?(@dummy.avatar.path)
      end

      should "store the thumbnail" do
        @dummy.save
        assert File.exists?(@dummy.avatar.path(:thumbnail))
      end
      
      should "return the correct path" do
        @dummy.save
        assert @dummy.avatar.url =~ /^\/system\/avatars\/1\/original\/5k.png\?\d*$/
      end
    end
  
    context "fog" do

      setup do
        rebuild_model(@options)
      end

      should "be extended by the DelayedFog module" do
        assert Dummy.new.avatar.is_a?(Paperclip::Storage::DelayedFog)
      end

      context "when assigned" do
        setup do
          @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.avatar = @file
        end

        teardown do
          @file.close
          directory = @connection.directories.new(:key => @fog_directory)
          directory.files.each {|file| file.destroy}
          directory.destroy
        end

        context "without a bucket" do
          setup do
            @connection.directories.get(@fog_directory).destroy
          end

          should "create the bucket" do
            assert @dummy.save
          
            # Upload the files so normal fog functionality can be tested
            @dummy.avatar.upload
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
          
            # Upload the files so normal fog functionality can be tested
            @dummy.avatar.upload
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
          
            # Upload the files so normal fog functionality can be tested
            @dummy.avatar.upload
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
              :fog_public       => true,
              :path             => ":attachment/:basename.:extension",
              :storage          => :delayed_fog
            )
            @dummy = Dummy.new
            @dummy.avatar = StringIO.new('.')
            @dummy.save
          
            # Upload the files so normal fog functionality can be tested
            @dummy.avatar.upload
          end

          should "provide a public url" do
            assert @dummy.avatar.url =~ /^http:\/\/img[0123]\.example\.com\/avatars\/stringio\.txt\?\d*$/
          end
        end

      end

    end
  end
end
