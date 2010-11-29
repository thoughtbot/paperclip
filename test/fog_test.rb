require './test/helper'
require 'fog'

Fog.mock!

class FogTest < Test::Unit::TestCase
  context "" do

    setup do
      @fog_directory = 'papercliptests'

      @credentials = {
        :provider               => 'AWS',
        :aws_access_key_id      => 'ID',
        :aws_secret_access_key  => 'SECRET'
      }

      @connection = Fog::Storage.new(@credentials)

      rebuild_model(
        :fog_directory    => @fog_directory,
        :fog_credentials  => @credentials,
        :fog_host         => nil,
        :fog_public       => true,
        :path             => ":attachment/:basename.:extension",
        :storage          => :fog
      )
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
        should "succeed" do
          assert @dummy.save
        end
      end

      context "with a bucket" do
        setup do
          @connection.directories.create(:key => @fog_directory)
        end

        should "succeed" do
          assert @dummy.save
        end
      end

      context "without a fog_host" do
        setup do
          rebuild_model(
            :fog_directory    => @fog_directory,
            :fog_credentials  => @credentials,
            :fog_host         => nil,
            :fog_public       => true,
            :path             => ":attachment/:basename.:extension",
            :storage          => :fog
          )
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
          rebuild_model(
            :fog_directory    => @fog_directory,
            :fog_credentials  => @credentials,
            :fog_host         => 'http://example.com',
            :fog_public       => true,
            :path             => ":attachment/:basename.:extension",
            :storage          => :fog
          )
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should "provide a public url" do
          assert @dummy.avatar.url =~ /^http:\/\/example\.com\/avatars\/stringio\.txt\?\d*$/
        end
      end

    end

  end
end
