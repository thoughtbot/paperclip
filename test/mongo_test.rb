require './test/helper'

class MongoTest < Test::Unit::TestCase
  def rails_env(env)
    silence_warnings do
      Object.const_set(:Rails, stub('Rails', :env => env))
    end
  end

  begin
    require 'bson'
    require 'mongo'

    begin
      if Mongo::Connection.new then
        context "" do 
          setup do
            @conn = Mongo::Connection.new
            @db_name = "paperclip-test"
            @db = @conn.db(@db_name)
          end

          teardown { @conn.close }

          context "" do
            setup do
              rebuild_model :storage => :mongo, 
              :mongo_frontend_path => 'uploads', 
              :mongo_frontend_host => 'somehost.com', 
              :mongo_database => @db,
              :path => ":attachment/:basename.:extension"
              @dummy = Dummy.new
              @dummy.avatar = StringIO.new(".")
            end
            should "generate an absolute path" do
              assert_match %r{^http://somehost.com/uploads/avatars/stringio.txt}, @dummy.avatar.url
            end
          end

          context "" do
            setup do
              rebuild_model :storage => :mongo, 
              :mongo_frontend_path => 'uploads', 
              :mongo_frontend_host => 'somehost.com', 
              :mongo_database => @db, 
              :path => ":attachment/:basename.:extension",
              :url => ":mongo_relative_url"
              @dummy = Dummy.new
              @dummy.avatar = StringIO.new(".")
            end
            should "generate a relative path" do
              assert_match %r{^/uploads/avatars/stringio.txt}, @dummy.avatar.url
            end
          end

          context "An attachment with MongoDB GridFS storage" do
            setup do
              rebuild_model :storage => :mongo,
              :mongo_frontend_path => 'uploads',
              :mongo_frontend_host => 'somehost.com',
              :mongo_database => @db,
              :path => ":attachment/:id/:style.:extension",
              :url => ":mongo_relative_url",
              :styles => { :thumb => "100x100", :square => "32x32#" }
            end
            should "be extended by the Mongo module" do
              assert Dummy.new.avatar.is_a?(Paperclip::Storage::Mongo)
            end

            should "not be extended by the Filesystem or S3 modules" do
              assert ! (Dummy.new.avatar.is_a?(Paperclip::Storage::Filesystem) || Dummy.new.avatar.is_a?(Paperclip::Storage::S3))
            end

            context "when assigned" do
              setup do
                @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
                @dummy = Dummy.new
                @dummy.avatar = @file
              end
              teardown { @file.close }

              context "and saved" do
                setup do
                  @dummy.save
                  @avatar_file = @dummy.avatar.to_file
                end

                should "succeed" do
                  assert @avatar_file.size == @file.size
                  assert true
                end

                should "still return a Tempfile when sent #to_file" do
                  assert @dummy.avatar.to_file.is_a?(Paperclip::Tempfile)
                end

                should "generate a tempfile with the right name" do
                  file = @dummy.avatar.to_file
                  assert_match /^original.*\.png$/, File.basename(file.path)
                end

                should "exist" do
                  assert @dummy.avatar.exists?
                end
              end

            end
          end

          context "teardown" do
            #teardown { @conn.drop_database(@db_name); @conn.close }
            teardown {  puts "\nGridFS for #{@db_name} created, you may want to drop it after testing\n"; }
            should "succeed" do 
              assert true
            end
          end
        end
      end
    rescue Mongo::ConnectionFailure => cf
      cf.message << " (Mongo storage module testing could not be completed)"
      puts cf.message
    end
  rescue LoadError => e
    e.message << " (You may need to install the mongo gem)"
    puts e.message
  end

end