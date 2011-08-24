module AWSS3Methods
  def load_s3
    begin
      require 'aws/s3'
    rescue LoadError => e
      fail "You do not have aws-s3 installed."
    end
  end

  def assert_credentials(key, secret)
    load_s3
    begin
      AWS::S3::Base.establish_connection!(
        :access_key_id => key,
        :secret_access_key => secret
      )
      AWS::S3::Service.buckets
    rescue AWS::S3::ResponseError => e
      fail "Could not connect using AWS credentials in AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY. " +
           "Please make sure these are set in your environment."
    end
  end
end

World(AWSS3Methods)
