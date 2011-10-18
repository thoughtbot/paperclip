require './test/helper'
require 'aws/s3'

class S3Test < Test::Unit::TestCase
  def rails_env(env)
    silence_warnings do
      Object.const_set(:Rails, stub('Rails', :env => env))
    end
  end

  context "Parsing S3 credentials" do
    setup do
      @proxy_settings = {:host => "127.0.0.1", :port => 8888, :user => "foo", :password => "bar"}
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :http_proxy => @proxy_settings,
                    :s3_credentials => {:not => :important}

      @dummy = Dummy.new
      @avatar = @dummy.avatar
    end

    should "get the correct credentials when RAILS_ENV is production" do
      rails_env("production")
      assert_equal({:key => "12345"},
                   @avatar.parse_credentials('production' => {:key => '12345'},
                                             :development => {:key => "54321"}))
    end

    should "get the correct credentials when RAILS_ENV is development" do
      rails_env("development")
      assert_equal({:key => "54321"},
                   @avatar.parse_credentials('production' => {:key => '12345'},
                                             :development => {:key => "54321"}))
    end

    should "return the argument if the key does not exist" do
      rails_env("not really an env")
      assert_equal({:test => "12345"}, @avatar.parse_credentials(:test => "12345"))
    end

    should "support HTTP proxy settings" do
      rails_env("development")
      assert_equal(true, @avatar.using_http_proxy?)
      assert_equal(@proxy_settings[:host], @avatar.http_proxy_host)
      assert_equal(@proxy_settings[:port], @avatar.http_proxy_port)
      assert_equal(@proxy_settings[:user], @avatar.http_proxy_user)
      assert_equal(@proxy_settings[:password], @avatar.http_proxy_password)
    end

  end

  context "" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => {},
                    :bucket => "bucket",
                    :path => ":attachment/:basename.:extension",
                    :url => ":s3_path_url"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on an S3 path" do
      assert_match %r{^http://s3.amazonaws.com/bucket/avatars/stringio.txt}, @dummy.avatar.url
    end
  end

  context "s3_host_name" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => {},
                    :bucket => "bucket",
                    :path => ":attachment/:basename.:extension",
                    :s3_host_name => "s3-ap-northeast-1.amazonaws.com"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on an :s3_host_name path" do
      assert_match %r{^http://s3-ap-northeast-1.amazonaws.com/bucket/avatars/stringio.txt}, @dummy.avatar.url
    end
  end

  context "An attachment that uses S3 for storage and has styles that return different file types" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :styles  => { :large => ['500x500#', :jpg] },
                    :storage => :s3,
                    :bucket  => "bucket",
                    :path => ":attachment/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }

      @dummy = Dummy.new
      @dummy.avatar = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', '5k.png'), 'rb')
    end

    should "return a url containing the correct original file mime type" do
      assert_match /.+\/5k.png/, @dummy.avatar.url
    end

    should "return a url containing the correct processed file mime type" do
      assert_match /.+\/5k.jpg/, @dummy.avatar.url(:large)
    end
  end

  context "An attachment that uses S3 for storage and has spaces in file name" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :styles  => { :large => ['500x500#', :jpg] },
                    :storage => :s3,
                    :bucket  => "bucket",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }

      @dummy = Dummy.new
      @dummy.avatar = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', 'spaced file.png'), 'rb')
    end

    should "return an unescaped version for path" do
      assert_match /.+\/spaced file\.png/, @dummy.avatar.path
    end

    should "return an escaped version for url" do
      assert_match /.+\/spaced%20file\.png/, @dummy.avatar.url
    end
  end

  context "" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => {},
                    :bucket => "bucket",
                    :path => ":attachment/:basename.:extension",
                    :url => ":s3_domain_url"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on an S3 subdomain" do
      assert_match %r{^http://bucket.s3.amazonaws.com/avatars/stringio.txt}, @dummy.avatar.url
    end
  end

  context "" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => {
                      :production   => { :bucket => "prod_bucket" },
                      :development  => { :bucket => "dev_bucket" }
                    },
                    :s3_host_alias => "something.something.com",
                    :path => ":attachment/:basename.:extension",
                    :url => ":s3_alias_url"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on the host_alias" do
      assert_match %r{^http://something.something.com/avatars/stringio.txt}, @dummy.avatar.url
    end
  end

  context "generating a url with a proc as the host alias" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => { :bucket => "prod_bucket" },
                    :s3_host_alias => Proc.new{|atch| "cdn#{atch.instance.counter % 4}.example.com"},
                    :path => ":attachment/:basename.:extension",
                    :url => ":s3_alias_url"
      Dummy.class_eval do
        def counter
          @counter ||= 0
          @counter += 1
          @counter
        end
      end
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on the host_alias" do
      assert_match %r{^http://cdn1.example.com/avatars/stringio.txt}, @dummy.avatar.url
      assert_match %r{^http://cdn2.example.com/avatars/stringio.txt}, @dummy.avatar.url
    end

    should "still return the bucket name" do
      assert_equal "prod_bucket", @dummy.avatar.bucket_name
    end

  end

  context "" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => {},
                    :bucket => "bucket",
                    :path => ":attachment/:basename.:extension",
                    :url => ":asset_host"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a relative URL for Rails to calculate assets host" do
      assert_match %r{^avatars/stringio\.txt}, @dummy.avatar.url
    end
  end

  context "Generating a secure url with an expiration" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => {
                      :production   => { :bucket => "prod_bucket" },
                      :development  => { :bucket => "dev_bucket" }
                    },
                    :s3_host_alias => "something.something.com",
                    :s3_permissions => "private",
                    :path => ":attachment/:basename.:extension",
                    :url => ":s3_alias_url"

      rails_env("production")

      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")

      AWS::S3::S3Object.expects(:url_for).with("avatars/stringio.txt", "prod_bucket", { :expires_in => 3600, :use_ssl => true })

      @dummy.avatar.expiring_url
    end

    should "should succeed" do
      assert true
    end
  end

  context "Generating a url with an expiration" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => {
                      :production   => { :bucket => "prod_bucket" },
                      :development  => { :bucket => "dev_bucket" }
                    },
                    :s3_permissions => :private,
                    :s3_host_alias => "something.something.com",
                    :path => ":attachment/:style/:basename.:extension",
                    :url => ":s3_alias_url"

      rails_env("production")

      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")

      AWS::S3::S3Object.expects(:url_for).with("avatars/original/stringio.txt", "prod_bucket", { :expires_in => 3600, :use_ssl => true })
      @dummy.avatar.expiring_url

      AWS::S3::S3Object.expects(:url_for).with("avatars/thumb/stringio.txt", "prod_bucket", { :expires_in => 1800, :use_ssl => true })
      @dummy.avatar.expiring_url(1800, :thumb)
    end

    should "should succeed" do
      assert true
    end
  end

  context "Parsing S3 credentials with a bucket in them" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => {
                      :production   => { :bucket => "prod_bucket" },
                      :development  => { :bucket => "dev_bucket" }
                    }
      @dummy = Dummy.new
    end

    should "get the right bucket in production" do
      rails_env("production")
      assert_equal "prod_bucket", @dummy.avatar.bucket_name
    end

    should "get the right bucket in development" do
      rails_env("development")
      assert_equal "dev_bucket", @dummy.avatar.bucket_name
    end
  end

  context "Parsing S3 credentials with a s3_host_name in them" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :s3_credentials => {
                      :production   => { :s3_host_name => "s3-world-end.amazonaws.com" },
                      :development  => { :s3_host_name => "s3-ap-northeast-1.amazonaws.com" }
                    }
      @dummy = Dummy.new
    end

    should "get the right s3_host_name in production" do
      rails_env("production")
      assert_match %r{^s3-world-end.amazonaws.com}, @dummy.avatar.s3_host_name
    end

    should "get the right s3_host_name in development" do
      rails_env("development")
      assert_match %r{^s3-ap-northeast-1.amazonaws.com}, @dummy.avatar.s3_host_name
    end

    should "get the right s3_host_name if the key does not exist" do
      rails_env("test")
      assert_match %r{^s3.amazonaws.com}, @dummy.avatar.s3_host_name
    end
  end

  context "An attachment with S3 storage" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :path => ":attachment/:style/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }
    end

    should "be extended by the S3 module" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::S3)
    end

    should "not be extended by the Filesystem module" do
      assert ! Dummy.new.avatar.is_a?(Paperclip::Storage::Filesystem)
    end

    context "when assigned" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', '5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      should "not get a bucket to get a URL" do
        @dummy.avatar.expects(:s3).never
        @dummy.avatar.expects(:s3_bucket).never
        assert_match %r{^http://s3\.amazonaws\.com/testing/avatars/original/5k\.png}, @dummy.avatar.url
      end

      context "and saved" do
        setup do
          AWS::S3::S3Object.stubs(:store).with(@dummy.avatar.path, anything, 'testing', :content_type => 'image/png', :access => :public_read)
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end

      should "delete tempfiles" do
        AWS::S3::S3Object.stubs(:store).with(@dummy.avatar.path, anything, 'testing', :content_type => 'image/png', :access => :public_read)
        File.stubs(:exist?).returns(true)
        Paperclip::Tempfile.any_instance.expects(:close).at_least_once()
        Paperclip::Tempfile.any_instance.expects(:unlink).at_least_once()

        @dummy.save!
      end

      context "and saved without a bucket" do
        setup do
          class AWS::S3::NoSuchBucket < AWS::S3::ResponseError
            # Force the class to be created as a proper subclass of ResponseError thanks to AWS::S3's autocreation of exceptions
          end
          AWS::S3::Bucket.expects(:create).with("testing")
          AWS::S3::S3Object.stubs(:store).raises(AWS::S3::NoSuchBucket.new(:message, :response)).then.returns(true)
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end

      context "and remove" do
        setup do
          AWS::S3::S3Object.stubs(:exists?).returns(true)
          AWS::S3::S3Object.stubs(:delete)
          @dummy.destroy_attached_files
        end

        should "succeed" do
          assert true
        end
      end
    end
  end

  context "An attachment with S3 storage and bucket defined as a Proc" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :bucket => lambda { |attachment| "bucket_#{attachment.instance.other}" },
                    :s3_credentials => {:not => :important}
    end

    should "get the right bucket name" do
      assert "bucket_a", Dummy.new(:other => 'a').avatar.bucket_name
      assert "bucket_b", Dummy.new(:other => 'b').avatar.bucket_name
    end
  end

  context "An attachment with S3 storage and specific s3 headers set" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :path => ":attachment/:style/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    },
                    :s3_headers => {'Cache-Control' => 'max-age=31557600'}
    end

    context "when assigned" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', '5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      context "and saved" do
        setup do
          AWS::S3::Base.stubs(:establish_connection!)
          AWS::S3::S3Object.stubs(:store).with(@dummy.avatar.path,
                                               anything,
                                               'testing',
                                               :content_type => 'image/png',
                                               :access => :public_read,
                                               'Cache-Control' => 'max-age=31557600')
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end
    end
  end

  context "with S3 credentials supplied as Pathname" do
     setup do
       ENV['S3_KEY']    = 'pathname_key'
       ENV['S3_BUCKET'] = 'pathname_bucket'
       ENV['S3_SECRET'] = 'pathname_secret'

       rails_env('test')

       rebuild_model :storage        => :s3,
                     :s3_credentials => Pathname.new(File.join(File.dirname(__FILE__))).join("../fixtures/s3.yml")

       Dummy.delete_all
       @dummy = Dummy.new
     end

     should "parse the credentials" do
       assert_equal 'pathname_bucket', @dummy.avatar.bucket_name
       assert_equal 'pathname_key', AWS::S3::Base.connection.options[:access_key_id]
       assert_equal 'pathname_secret', AWS::S3::Base.connection.options[:secret_access_key]
     end
  end

  context "with S3 credentials in a YAML file" do
    setup do
      ENV['S3_KEY']    = 'env_key'
      ENV['S3_BUCKET'] = 'env_bucket'
      ENV['S3_SECRET'] = 'env_secret'

      rails_env('test')

      rebuild_model :storage        => :s3,
                    :s3_credentials => File.new(File.join(File.dirname(__FILE__), "../fixtures/s3.yml"))

      Dummy.delete_all

      @dummy = Dummy.new
    end

    should "run the file through ERB" do
      assert_equal 'env_bucket', @dummy.avatar.bucket_name
      assert_equal 'env_key', AWS::S3::Base.connection.options[:access_key_id]
      assert_equal 'env_secret', AWS::S3::Base.connection.options[:secret_access_key]
    end
  end

  context "S3 Permissions" do
    context "defaults to public-read" do
      setup do
        rebuild_model :storage => :s3,
                      :bucket => "testing",
                      :path => ":attachment/:style/:basename.:extension",
                      :s3_credentials => {
                        'access_key_id' => "12345",
                        'secret_access_key' => "54321"
                      }
      end

      context "when assigned" do
        setup do
          @file = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', '5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.avatar = @file
        end

        teardown { @file.close }

        context "and saved" do
          setup do
            AWS::S3::Base.stubs(:establish_connection!)
            AWS::S3::S3Object.expects(:store).with(@dummy.avatar.path,
                                                 anything,
                                                 'testing',
                                                 :content_type => 'image/png',
                                                 :access => :public_read)
            @dummy.save
          end

          should "succeed" do
            assert true
          end
        end
      end
    end

    context "string permissions set" do
      setup do
        rebuild_model :storage => :s3,
                      :bucket => "testing",
                      :path => ":attachment/:style/:basename.:extension",
                      :s3_credentials => {
                        'access_key_id' => "12345",
                        'secret_access_key' => "54321"
                      },
                      :s3_permissions => 'private'
      end

      context "when assigned" do
        setup do
          @file = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', '5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.avatar = @file
        end

        teardown { @file.close }

        context "and saved" do
          setup do
            AWS::S3::Base.stubs(:establish_connection!)
            AWS::S3::S3Object.expects(:store).with(@dummy.avatar.path,
                                                   anything,
                                                   'testing',
                                                   :content_type => 'image/png',
                                                   :access => 'private')
            @dummy.save
          end

          should "succeed" do
            assert true
          end
        end
      end
    end

    context "hash permissions set" do
      setup do
        rebuild_model :storage => :s3,
                      :bucket => "testing",
                      :path => ":attachment/:style/:basename.:extension",
                      :styles => {
                         :thumb => "80x80>"
                      },
                      :s3_credentials => {
                        'access_key_id' => "12345",
                        'secret_access_key' => "54321"
                      },
                      :s3_permissions => {
                        :original => 'private',
                        :thumb => 'public-read'
                      }
      end

      context "when assigned" do
        setup do
          @file = File.new(File.join(File.dirname(__FILE__), '..', 'fixtures', '5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.avatar = @file
        end

        teardown { @file.close }

        context "and saved" do
          setup do
            AWS::S3::Base.stubs(:establish_connection!)
            [:thumb, :original].each do |style|
              AWS::S3::S3Object.expects(:store).with("avatars/#{style}/5k.png",
                                                    anything,
                                                    'testing',
                                                    :content_type => 'image/png',
                                                    :access => style == :thumb ? 'public-read' : 'private')
            end
            @dummy.save
          end

          should "succeed" do
            assert true
          end
        end
      end
    end
  end
end
