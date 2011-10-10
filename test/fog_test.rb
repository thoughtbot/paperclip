require './test/helper'
require 'fog'

Fog.mock!

class FogTest < Test::Unit::TestCase
  context "" do

    context "with credentials provided in a path string" do
      setup do
        rebuild_model :styles => { :medium => "300x300>", :thumb => "100x100>" },
                      :storage => :fog,
                      :url => '/:attachment/:filename',
                      :fog_directory => "paperclip",
                      :fog_credentials => File.join(File.dirname(__FILE__), 'fixtures', 'fog.yml')
        @dummy = Dummy.new
        @dummy.avatar = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
      end

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
                      :fog_credentials => File.open(File.join(File.dirname(__FILE__), 'fixtures', 'fog.yml'))
        @dummy = Dummy.new
        @dummy.avatar = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
      end

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
        @dummy = Dummy.new
        @dummy.avatar = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
      end
      should "be able to interpolate the path without blowing up" do
        assert_equal File.expand_path(File.join(File.dirname(__FILE__), "../public/avatars/5k.png")),
                     @dummy.avatar.path
      end

      should "clean up file objects" do
        File.stubs(:exist?).returns(true)
        Paperclip::Tempfile.any_instance.expects(:close).at_least_once()
        Paperclip::Tempfile.any_instance.expects(:unlink).at_least_once()

        @dummy.save!
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
          assert_equal false, @dummy.avatar.options.fog_public
        end
      end

    end

  end
end
