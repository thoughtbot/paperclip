module Paperclip
  module Interpolations
    # Returns the youtube_id of the instance.
    def youtube_id attachment, style
      attachment.instance.youtube_id
    end
  end

  module Storage
    # Youtube video hosting, easy place to share videos for
    # You can find at http://www.youtube.com/
    # There are a few S3-specific options for has_attached_file:
    # * +youtube_credentials+: Takes a path, a File, or a Hash. The path (or File) must point
    #   to a YAML file containing the +login_name+ and +login_password+ and +youttube_username+ 
    #	and +developer_key+ that you can got it from your account on Youtube.
    #   You can 'environment-space' this just like you do to your
    #   database.yml file, so different environments can use different accounts:
    #     development:
    #       login_name: dr-click...
    #       login_password: 123...
    #     production:
    #       login_name: dr-click...
    #       login_password: 123...
    #   

    module Youtube
      def self.extended base
        begin
          require 'net/http'
        rescue LoadError => e
          log("(Error) #{e.message}")
          e.message << " (Can't find required library 'net/http')"
          raise e
        end
        begin
          require 'net/https'
        rescue LoadError => e
          log("(Error) #{e.message}")
          e.message << " (Can't find required library 'net/https')"
          raise e
        end
        begin
          require 'mime/types'
        rescue LoadError => e
          log("(Error) #{e.message}")
          e.message << " (You may need to install the mime-types gem)"
          raise e
        end
        begin
          require 'builder'
        rescue LoadError => e
          log("(Error) #{e.message}")
          e.message << " (You may need to install the builder gem)"
          raise e
        end
        begin
          require 'rexml/document'
        rescue LoadError => e
          log("(Error) #{e.message}")
          e.message << " (Can't find required library 'rexml/document')"
          raise e
        end
        
        base.instance_eval do
          @youtube_options = @options[:youtube_options] || {}
          
          @developer_key = @options[:developer_key] || @youtube_options[:developer_key]
          @login_name = @options[:login_name] || @youtube_options[:login_name]
          @login_password = @options[:login_password] || @youtube_options[:login_password]
          @youttube_username = @options[:youttube_username] || @youtube_options[:youttube_username]
          
          @auth_host = @options[:auth_host] || @youtube_options[:auth_host] || 'www.google.com'
          @auth_path = @options[:auth_path] || @youtube_options[:auth_path] || '/youtube/accounts/ClientLogin'
          
          @upload_host = @options[:upload_host] || @youtube_options[:upload_host] || 'uploads.gdata.youtube.com'
          @upload_path = @options[:upload_path] || @youtube_options[:upload_path] || "/feeds/api/users/#{@youttube_username}/uploads"
          
          @data_host = @options[:data_host] || @youtube_options[:data_host] || 'gdata.youtube.com'
        end
        
        Paperclip.interpolates(:youtube_url) do |attachment, style|
            style = :thumbnail_1 if style == :thumbnail
            if style == :original
              'http://www.youtube.com/watch?v=:youtube_id'
            else
              "http://i.ytimg.com/vi/:youtube_id/#{style.to_s.split('_').last.to_i}.jpg" 
            end
        end
      end
      
      def login_name
        @login_name
      end
      def login_password
        @login_password
      end
      def developer_key
        @developer_key
      end
      def youttube_username
        @youttube_username
      end
      def auth_host
        @auth_host
      end
      def auth_path
        @auth_path
      end
      def upload_host
        @upload_host
      end
      def upload_path
        @upload_path
      end
      def data_host
        @data_host
      end
      def token
        @token ||= begin
          http = Net::HTTP.new("www.google.com", 443)
          http.use_ssl = true
          body = "Email=#{YoutubeChain.esc login_name}&Passwd=#{YoutubeChain.esc login_password}&service=youtube&source=#{YoutubeChain.esc youttube_username}"
          response = http.post("/youtube/accounts/ClientLogin", body, "Content-Type" => "application/x-www-form-urlencoded")
          raise response.body[/Error=(.+)/,1] if response.code.to_i != 200
          @token = response.body[/Auth=(.+)/, 1]
        end
      end
      
      def update_youtube_id(data)
        doc = REXML::Document.new data
        id = doc.root.elements["id"].text.split("/").last if doc && doc.root
        
        if id
          video = Video.find self.instance.id
          video.update_attribute(:youtube_id, id)
        else
          log("(Error) Video has no id, please reupload to Youtube.")
          raise "Video has no id, please reupload to Youtube."
        end
      end
      
      def youtube_delete
        http = Net::HTTP.new(data_host)
        headers = {
          'Content-Type' => 'application/atom+xml',
          'Authorization' => "GoogleLogin auth=#{token}",
          'GData-Version' => '2',
          'X-GData-Key' => "key=#{developer_key}"
        }
        
        resp = http.delete(upload_path+"/#{self.instance.youtube_id}", headers)
        if resp.code != "200"
          log("(Error) Couldn't delete the video from Youtube")
          raise "Couldn't delete the video from Youtube"
        end
      end

      def exists?(style_name = default_style)
        http = Net::HTTP.new(data_host)
        headers = {
          'Content-Type' => 'application/atom+xml',
          'Authorization' => "GoogleLogin auth=#{token}",
          'GData-Version' => '2',
          'X-GData-Key' => "key=#{developer_key}"
        }
        
        resp= http.get(upload_path+"/#{self.instance.youtube_id}", headers)
        if resp.code == "200"
          return true
        elsif
          log("(Error) Couldn't find the video '#{self.instance.youtube_id}'")
          return false
        end
      end
      
      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style_name = default_style
      end
      
      def boundary 
        "An43094fu"
      end
      
      def request_xml(opts)
        b = Builder::XmlMarkup.new
        b.instruct!
        b.entry(:xmlns => "http://www.w3.org/2005/Atom", 'xmlns:media' => "http://search.yahoo.com/mrss/", 'xmlns:yt' => "http://gdata.youtube.com/schemas/2007") do | m |
          m.tag!("media:group") do | mg |
            mg.tag!("media:title", opts[:title], :type => "plain")
            mg.tag!("media:description", opts[:description], :type => "plain")
            mg.tag!("media:keywords", opts[:keywords].join(","))
            mg.tag!('media:category', opts[:category], :scheme => "http://gdata.youtube.com/schemas/2007/categories.cat")
            mg.tag!('yt:private') if opts[:private]
          end
        end.to_s
      end
      
      def request_io(data, opts)
        post_body = [
          "--#{boundary}\r\n",
          "Content-Type: application/atom+xml; charset=UTF-8\r\n\r\n",
          request_xml(opts),
          "\r\n--#{boundary}\r\n",
          "Content-Type: #{opts[:mime_type]}\r\nContent-Transfer-Encoding: binary\r\n\r\n",
          data,
          "\r\n--#{boundary}--\r\n",
        ]
        
        YoutubeChain.new(post_body)
      end
      
      def authorization_headers
        {
          "Authorization"  => "GoogleLogin auth=#{token}",
          "X-GData-Client" => "#{youttube_username}",
          "X-GData-Key"    => "key=#{developer_key}"
        }
      end
      
      def youtube_upload(data, video_file)
        opts = { :mime_type => MIME::Types.type_for(video_file).join(),
                  :title => self.instance.respond_to?(:title) && !self.instance.title.blank? ? self.instance.title.blank? :  video_file,
                  :description => self.instance.respond_to?(:description) && !self.instance.description.blank? ? self.instance.description.blank? :  video_file,
                  :category => 'People',
                  :keywords => [],
                  :filename => video_file}
        
        post_body_io = request_io(data, opts)
        upload_headers = authorization_headers.merge({
            "Slug"           => "#{opts[:filename]}",
            "Content-Type"   => "multipart/related; boundary=#{boundary}",
            "Content-Length" => "#{post_body_io.expected_length}"
        })
        
        path = upload_path
        
        Net::HTTP.start(upload_host) do | session |
          post = Net::HTTP::Post.new(path, upload_headers)
          post.body_stream = post_body_io
          response = session.request(post)
          
          if response.code == "201"
            update_youtube_id response.body
          else
            log("(Error) Couldn't upload the video to Youtube >> #{response.body}")
            raise "Couldn't upload the video to Youtube >> #{response.body}"
          end
        end
      end
      
      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            log("Uploading to youtube : #{self.instance.media_file_name}")
            youtube_upload(File.open(file.path), self.instance.media_file_name)
          rescue => e
            log("(Error) #{e.message} - #{e.backtrace.inspect}")
            raise e.message
          end
        end
        @queued_for_write = {}
      end
      
      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log("deleting from youtube : #{self.instance.youtube_id}")
            youtube_delete
          rescue => e
            log("(Error) #{e.message}")
            raise e.message
          end
        end
        @queued_for_delete = []
      end
    end


  end
end


class YoutubeChain
  attr_accessor :autoclose
  def self.esc(s)
    s.to_s.gsub(/[^ \w.-]+/n){'%'+($&.unpack('H2'*$&.size)*'%').upcase}.tr(' ', '+')
  end

  def initialize(*any_ios)
    @autoclose = true
    @chain = any_ios.flatten.map{|e| e.respond_to?(:read)  ? e : StringIO.new(e.to_s) }
  end

  def read(buffer_size = 1024)
    current_io = @chain.shift
    return false if !current_io
    
    buf = current_io.read(buffer_size)
    if !buf && @chain.empty? # End of streams
      release_handle(current_io) if @autoclose
      false
    elsif !buf # This IO is depleted, but next one is available
      release_handle(current_io) if @autoclose
      read(buffer_size)
    elsif buf.length < buffer_size # This IO is depleted, but we were asked for more
      release_handle(current_io) if @autoclose
      buf + (read(buffer_size - buf.length) || '') # and recurse
    else # just return the buffer
      @chain.unshift(current_io) # put the current back
      buf
    end
  end
    
  def expected_length
    @chain.inject(0) do | len, io |
      if io.respond_to?(:length)
        len + (io.length - io.pos)
      elsif io.is_a?(File)
        len + File.size(io.path) - io.pos
      else
        raise "Cannot predict length of #{io.inspect}"
      end
    end
  end
    
  private
  def release_handle(io)
    io.close if io.respond_to?(:close)
  end
end
