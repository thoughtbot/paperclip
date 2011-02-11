module MongoMethods
  def load_mongo
    begin
      require 'mongo'
    rescue LoadError => e
      fail "You do not have aws-s3 installed."
    end
  end

  def mongo_connect
    load_mongo
    begin
      Mongo::Connection.new
    rescue Mongo::ConnectionFailure => e
      fail "Could not connect to MongoDB on localhost."
    end
  end
end

World(MongoMethods)
