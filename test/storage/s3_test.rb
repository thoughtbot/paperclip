require './test/helper'
require 'aws'

class S3Test < Test::Unit::TestCase
  def rails_env(env)
    silence_warnings do
      Object.const_set(:Rails, stub('Rails', :env => env))
    end
  end

  def setup
    AWS.config(:access_key_id => "TESTKEY", :secret_access_key => "TESTSECRET", :stub_requests => true)
  end

  def teardown
    AWS.config(:access_key_id => nil, :secret_access_key => nil, :stub_requests => nil)
  end

  context "Parsing S3 credentials" do
    setup do
      @proxy_settings = {:host => "127.0.0.1", :port => 8888, :user => "foo", :password => "bar"}
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

  context ":bucket option via :s3_credentials" do

    setup do
      rebuild_model :storage => :s3, :s3_credentials => {:bucket => 'testing'}
      @dummy = Dummy.new
    end

    should "populate #bucket_name" do
      assert_equal @dummy.avatar.bucket_name, 'testing'
    end

  end

  context ":bucket option" do

    setup do
      rebuild_model :storage => :s3, :bucket => "testing", :s3_credentials => {}
      @dummy = Dummy.new
    end

    should "populate #bucket_name" do
      assert_equal @dummy.avatar.bucket_name, 'testing'
    end

  end

  context "missing :bucket option" do

    setup do
      rebuild_model :storage => :s3,
                    :http_proxy => @proxy_settings,
                    :s3_credentials => {:not => :important}

      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")

    end

    should "raise an argument error" do
      exception = assert_raise(ArgumentError) { @dummy.save }
      assert_match /missing required :bucket option/, exception.message
    end

  end

  context "" do
    setup do
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

    should "use the correct bucket" do
      assert_equal "bucket", @dummy.avatar.s3_bucket.name
    end

    should "use the correct key" do
      assert_equal "avatars/stringio.txt", @dummy.avatar.s3_object.key
    end

  end

  context ":s3_protocol => 'https'" do
    setup do
      rebuild_model :storage => :s3,
                    :s3_credentials => {},
                    :s3_protocol => 'https',
                    :bucket => "bucket",
                    :path => ":attachment/:basename.:extension"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on an S3 path" do
      assert_match %r{^https://s3.amazonaws.com/bucket/avatars/stringio.txt}, @dummy.avatar.url
    end
  end

  context ":s3_protocol => ''" do
    setup do
      rebuild_model :storage => :s3,
                    :s3_credentials => {},
                    :s3_protocol => '',
                    :bucket => "bucket",
                    :path => ":attachment/:basename.:extension"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on an S3 path" do
      assert_match %r{^//s3.amazonaws.com/bucket/avatars/stringio.txt}, @dummy.avatar.url
    end
  end

  context "An attachment that uses S3 for storage and has the style in the path" do
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
                    }

      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
      @avatar = @dummy.avatar
    end

    should "use an S3 object based on the correct path for the default style" do
      assert_equal("avatars/original/stringio.txt", @dummy.avatar.s3_object.key)
    end

    should "use an S3 object based on the correct path for the custom style" do
      assert_equal("avatars/thumb/stringio.txt", @dummy.avatar.s3_object(:thumb).key)
    end
  end

  context "s3_host_name" do
    setup do
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

    should "use the S3 bucket with the correct host name" do
      assert_equal "s3-ap-northeast-1.amazonaws.com", @dummy.avatar.s3_bucket.config.s3_endpoint
    end
  end

  context "An attachment that uses S3 for storage and has styles that return different file types" do
    setup do
      rebuild_model :styles  => { :large => ['500x500#', :jpg] },
                    :storage => :s3,
                    :bucket  => "bucket",
                    :path => ":attachment/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }

      File.open(fixture_file('5k.png'), 'rb') do |file|
        @dummy = Dummy.new
        @dummy.avatar = file
      end
    end

    should "return a url containing the correct original file mime type" do
      assert_match /.+\/5k.png/, @dummy.avatar.url
    end

    should 'use the correct key for the original file mime type' do
      assert_match /.+\/5k.png/, @dummy.avatar.s3_object.key
    end

    should "return a url containing the correct processed file mime type" do
      assert_match /.+\/5k.jpg/, @dummy.avatar.url(:large)
    end

    should "use the correct key for the processed file mime type" do
      assert_match /.+\/5k.jpg/, @dummy.avatar.s3_object(:large).key
    end
  end

  context "An attachment that uses S3 for storage and has spaces in file name" do
    setup do
      rebuild_model :styles  => { :large => ['500x500#', :jpg] },
                    :storage => :s3,
                    :bucket  => "bucket",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }

      File.open(fixture_file('spaced file.png'), 'rb') do |file|
        @dummy = Dummy.new
        @dummy.avatar = file
      end
    end

    should "return a replaced version for path" do
      assert_match /.+\/spaced_file\.png/, @dummy.avatar.path
    end

    should "return a replaced version for url" do
      assert_match /.+\/spaced_file\.png/, @dummy.avatar.url
    end
  end

  context "An attachment that uses S3 for storage and has a question mark in file name" do
    setup do
      rebuild_model :styles  => { :large => ['500x500#', :jpg] },
                    :storage => :s3,
                    :bucket  => "bucket",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }

      file = Paperclip.io_adapters.for(StringIO.new("."))
      file.original_filename = "question?mark.png"
      @dummy = Dummy.new
      @dummy.avatar = file
      @dummy.save
    end

    should "return a replaced version for path" do
      assert_match /.+\/question_mark\.png/, @dummy.avatar.path
    end

    should "return a replaced version for url" do
      assert_match /.+\/question_mark\.png/, @dummy.avatar.url
    end
  end

  context "" do
    setup do
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
      @build_model_with_options = lambda {|options|
        base_options = {
          :storage => :s3,
          :s3_credentials => {
            :production   => { :bucket => "prod_bucket" },
            :development  => { :bucket => "dev_bucket" }
          },
          :s3_host_alias => "something.something.com",
          :s3_permissions => "private",
          :path => ":attachment/:basename.:extension",
          :url => ":s3_alias_url"
        }

        rebuild_model base_options.merge(options)
      }
    end

    should "use default options" do
      @build_model_with_options[{}]

      rails_env("production")

      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")

      object = stub
      @dummy.avatar.stubs(:s3_object).returns(object)
      object.expects(:url_for).with(:read, :expires => 3600, :secure => true)

      @dummy.avatar.expiring_url
    end

    should "allow overriding s3_url_options" do
      @build_model_with_options[:s3_url_options => { :response_content_disposition => "inline" }]

      rails_env("production")

      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")

      object = stub
      @dummy.avatar.stubs(:s3_object).returns(object)
      object.expects(:url_for).with(:read, :expires => 3600, :secure => true, :response_content_disposition => "inline")

      @dummy.avatar.expiring_url
    end

    should "allow overriding s3_object options with a proc" do
      @build_model_with_options[:s3_url_options => lambda {|attachment| { :response_content_type => attachment.avatar_content_type } }]

      rails_env("production")

      @dummy = Dummy.new

      @file = StringIO.new(".")
      @file.stubs(:original_filename).returns("5k.png\n\n")
      @file.stubs(:content_type).returns("image/png\n\n")
      @file.stubs(:to_tempfile).returns(@file)

      @dummy.avatar = @file

      object = stub
      @dummy.avatar.stubs(:s3_object).returns(object)
      object.expects(:url_for).with(:read, :expires => 3600, :secure => true, :response_content_type => "image/png")

      @dummy.avatar.expiring_url
    end
  end

  context "Generating a url with an expiration for each style" do
    setup do
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
    end

    should "should generate a url for the thumb" do
      object = stub
      @dummy.avatar.stubs(:s3_object).with(:thumb).returns(object)
      object.expects(:url_for).with(:read, :expires => 1800, :secure => true)
      @dummy.avatar.expiring_url(1800, :thumb)
    end

    should "should generate a url for the default style" do
      object = stub
      @dummy.avatar.stubs(:s3_object).with(:original).returns(object)
      object.expects(:url_for).with(:read, :expires => 1800, :secure => true)
      @dummy.avatar.expiring_url(1800)
    end
  end

  context "Parsing S3 credentials with a bucket in them" do
    setup do
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
      assert_equal "prod_bucket", @dummy.avatar.s3_bucket.name
    end

    should "get the right bucket in development" do
      rails_env("development")
      assert_equal "dev_bucket", @dummy.avatar.bucket_name
      assert_equal "dev_bucket", @dummy.avatar.s3_bucket.name
    end
  end

  context "Parsing S3 credentials with a s3_host_name in them" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => 'testing',
                    :s3_credentials => {
                      :production   => { :s3_host_name => "s3-world-end.amazonaws.com" },
                      :development  => { :s3_host_name => "s3-ap-northeast-1.amazonaws.com" }
                    }
      @dummy = Dummy.new
    end

    should "get the right s3_host_name in production" do
      rails_env("production")
      assert_match %r{^s3-world-end.amazonaws.com}, @dummy.avatar.s3_host_name
      assert_match %r{^s3-world-end.amazonaws.com}, @dummy.avatar.s3_bucket.config.s3_endpoint
    end

    should "get the right s3_host_name in development" do
      rails_env("development")
      assert_match %r{^s3-ap-northeast-1.amazonaws.com}, @dummy.avatar.s3_host_name
      assert_match %r{^s3-ap-northeast-1.amazonaws.com}, @dummy.avatar.s3_bucket.config.s3_endpoint
    end

    should "get the right s3_host_name if the key does not exist" do
      rails_env("test")
      assert_match %r{^s3.amazonaws.com}, @dummy.avatar.s3_host_name
      assert_match %r{^s3.amazonaws.com}, @dummy.avatar.s3_bucket.config.s3_endpoint
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
        @file = File.new(fixture_file('5k.png'), 'rb')
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
          object = stub
          @dummy.avatar.stubs(:s3_object).returns(object)
          object.expects(:write).with(anything,
                                      :content_type => "image/png",
                                      :acl => :public_read)
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end

      context "and saved without a bucket" do
        setup do
          AWS::S3::BucketCollection.any_instance.expects(:create).with("testing")
          AWS::S3::S3Object.any_instance.stubs(:write).
            raises(AWS::S3::Errors::NoSuchBucket.new(stub,
                                                     stub(:status => 404,
                                                          :body => "<foo/>"))).
            then.returns(nil)
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end

      context "and remove" do
        setup do
          AWS::S3::S3Object.any_instance.stubs(:exists?).returns(true)
          AWS::S3::S3Object.any_instance.stubs(:delete)
          @dummy.destroy_attached_files
        end

        should "succeed" do
          assert true
        end
      end

      context 'that the file were missing' do
        setup do
          AWS::S3::S3Object.any_instance.stubs(:exists?).raises(AWS::Errors::Base)
        end

        should 'return false on exists?' do
          assert !@dummy.avatar.exists?
        end
      end
    end
  end

  context "An attachment with S3 storage and bucket defined as a Proc" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => lambda { |attachment| "bucket_#{attachment.instance.other}" },
                    :s3_credentials => {:not => :important}
    end

    should "get the right bucket name" do
      assert "bucket_a", Dummy.new(:other => 'a').avatar.bucket_name
      assert "bucket_a", Dummy.new(:other => 'a').avatar.s3_bucket.name
      assert "bucket_b", Dummy.new(:other => 'b').avatar.bucket_name
      assert "bucket_b", Dummy.new(:other => 'b').avatar.s3_bucket.name
    end
  end

  context "An attachment with S3 storage and S3 credentials defined as a Proc" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => {:not => :important},
                    :s3_credentials => lambda { |attachment|
                      Hash['access_key_id' => "access#{attachment.instance.other}", 'secret_access_key' => "secret#{attachment.instance.other}"]
                    }
    end

    should "get the right credentials" do
      assert "access1234", Dummy.new(:other => '1234').avatar.s3_credentials[:access_key_id]
      assert "secret1234", Dummy.new(:other => '1234').avatar.s3_credentials[:secret_access_key]
    end
  end

  context "An attachment with S3 storage and specific s3 headers set" do
    setup do
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
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      context "and saved" do
        setup do
          object = stub
          @dummy.avatar.stubs(:s3_object).returns(object)
          object.expects(:write).with(anything,
                                      :content_type => "image/png",
                                      :acl => :public_read,
                                      :cache_control => 'max-age=31557600')
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end
    end
  end

  context "An attachment with S3 storage and metadata set using header names" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :path => ":attachment/:style/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    },
                    :s3_headers => {'x-amz-meta-color' => 'red'}
    end

    context "when assigned" do
      setup do
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      context "and saved" do
        setup do
          object = stub
          @dummy.avatar.stubs(:s3_object).returns(object)
          object.expects(:write).with(anything,
                                      :content_type => "image/png",
                                      :acl => :public_read,
                                      :metadata => { "color" => "red" })
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end
    end
  end

  context "An attachment with S3 storage and metadata set using the :s3_metadata option" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :path => ":attachment/:style/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    },
                    :s3_metadata => { "color" => "red" }
    end

    context "when assigned" do
      setup do
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      context "and saved" do
        setup do
          object = stub
          @dummy.avatar.stubs(:s3_object).returns(object)
          object.expects(:write).with(anything,
                                      :content_type => "image/png",
                                      :acl => :public_read,
                                      :metadata => { "color" => "red" })
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end
    end
  end

  context "An attachment with S3 storage and storage class set using the header name" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :path => ":attachment/:style/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    },
                    :s3_headers => { "x-amz-storage-class" => "reduced_redundancy" }
    end

    context "when assigned" do
      setup do
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      context "and saved" do
        setup do
          object = stub
          @dummy.avatar.stubs(:s3_object).returns(object)
          object.expects(:write).with(anything,
                                      :content_type => "image/png",
                                      :acl => :public_read,
                                      :storage_class => "reduced_redundancy")
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end
    end
  end

  context "An attachment with S3 storage and using AES256 encryption" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :path => ":attachment/:style/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    },
                    :s3_server_side_encryption => :aes256
    end

    context "when assigned" do
      setup do
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      context "and saved" do
        setup do
          object = stub
          @dummy.avatar.stubs(:s3_object).returns(object)
          object.expects(:write).with(anything,
                                      :content_type => "image/png",
                                      :acl => :public_read,
                                      :server_side_encryption => :aes256)
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end
    end
  end

  context "An attachment with S3 storage and storage class set using the :storage_class option" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :path => ":attachment/:style/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    },
                    :s3_storage_class => :reduced_redundancy
    end

    context "when assigned" do
      setup do
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      context "and saved" do
        setup do
          object = stub
          @dummy.avatar.stubs(:s3_object).returns(object)
          object.expects(:write).with(anything,
                                      :content_type => "image/png",
                                      :acl => :public_read,
                                      :storage_class => :reduced_redundancy)
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
                    :s3_credentials => Pathname.new(fixture_file('s3.yml'))

      Dummy.delete_all
      @dummy = Dummy.new
    end

    should "parse the credentials" do
      assert_equal 'pathname_bucket', @dummy.avatar.bucket_name
      assert_equal 'pathname_key', @dummy.avatar.s3_bucket.config.access_key_id
      assert_equal 'pathname_secret', @dummy.avatar.s3_bucket.config.secret_access_key
    end
  end

  context "with S3 credentials in a YAML file" do
    setup do
      ENV['S3_KEY']    = 'env_key'
      ENV['S3_BUCKET'] = 'env_bucket'
      ENV['S3_SECRET'] = 'env_secret'

      rails_env('test')

      rebuild_model :storage        => :s3,
                    :s3_credentials => File.new(fixture_file('s3.yml'))

      Dummy.delete_all

      @dummy = Dummy.new
    end

    should "run the file through ERB" do
      assert_equal 'env_bucket', @dummy.avatar.bucket_name
      assert_equal 'env_key', @dummy.avatar.s3_bucket.config.access_key_id
      assert_equal 'env_secret', @dummy.avatar.s3_bucket.config.secret_access_key
    end
  end

  context "S3 Permissions" do
    context "defaults to :public_read" do
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
          @file = File.new(fixture_file('5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.avatar = @file
        end

        teardown { @file.close }

        context "and saved" do
          setup do
            object = stub
            @dummy.avatar.stubs(:s3_object).returns(object)
            object.expects(:write).with(anything,
                                        :content_type => "image/png",
                                        :acl => :public_read)
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
                      :s3_permissions => :private
      end

      context "when assigned" do
        setup do
          @file = File.new(fixture_file('5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.avatar = @file
        end

        teardown { @file.close }

        context "and saved" do
          setup do
            object = stub
            @dummy.avatar.stubs(:s3_object).returns(object)
            object.expects(:write).with(anything,
                                        :content_type => "image/png",
                                        :acl => :private)
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
                        :original => :private,
                        :thumb => :public_read
                      }
      end

      context "when assigned" do
        setup do
          @file = File.new(fixture_file('5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.avatar = @file
        end

        teardown { @file.close }

        context "and saved" do
          setup do
            [:thumb, :original].each do |style|
              object = stub
              @dummy.avatar.stubs(:s3_object).with(style).returns(object)
              object.expects(:write).with(anything,
                                          :content_type => "image/png",
                                          :acl => style == :thumb ? :public_read : :private)
            end
            @dummy.save
          end

          should "succeed" do
            assert true
          end
        end
      end
    end

    context "proc permission set" do
      setup do
        rebuild_model(
          :storage => :s3,
          :bucket => "testing",
          :path => ":attachment/:style/:basename.:extension",
          :styles => {
             :thumb => "80x80>"
          },
          :s3_credentials => {
            'access_key_id' => "12345",
            'secret_access_key' => "54321"
          },
          :s3_permissions => lambda {|attachment, style|
            attachment.instance.private_attachment? && style.to_sym != :thumb ? :private : :public_read
          }
        )
      end

      context "when assigned" do
        setup do
          @file = File.new(fixture_file('5k.png'), 'rb')
          @dummy = Dummy.new
          @dummy.stubs(:private_attachment? => true)
          @dummy.avatar = @file
        end

        teardown { @file.close }

        context "and saved" do
          setup do
            @dummy.save
          end

          should "succeed" do
            assert @dummy.avatar.url().include?       "https://"
            assert @dummy.avatar.url(:thumb).include? "http://"
          end
        end
      end

    end
  end

  context "An attachment with S3 storage and metadata set using a proc as headers" do
    setup do
      rebuild_model(
        :storage => :s3,
        :bucket => "testing",
        :path => ":attachment/:style/:basename.:extension",
        :styles => {
          :thumb => "80x80>"
        },
        :s3_credentials => {
          'access_key_id' => "12345",
          'secret_access_key' => "54321"
        },
        :s3_headers => lambda {|attachment|
          {'Content-Disposition' => "attachment; filename=\"#{attachment.name}\""}
        }
      )
    end

    context "when assigned" do
      setup do
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.stubs(:name => 'Custom Avatar Name.png')
        @dummy.avatar = @file
      end

      teardown { @file.close }

      context "and saved" do
        setup do
          [:thumb, :original].each do |style|
            object = stub
            @dummy.avatar.stubs(:s3_object).with(style).returns(object)
            object.expects(:write).with(anything,
                                        :content_type => "image/png",
                                        :acl => :public_read,
                                        :content_disposition => 'attachment; filename="Custom Avatar Name.png"')
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
