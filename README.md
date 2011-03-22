Paperclip and Youtube
=========

The fork contains the Youtube api as a new sotrage for paperclip.

See the paperclip Readme file here
https://github.com/thoughtbot/paperclip

Requirements
------------

ImageMagick must be installed and Paperclip must have access to it. To ensure
that it does, on your command line, run `which convert` (one of the ImageMagick
utilities). This will give you the path where that utility is installed. For
example, it might return `/usr/local/bin/convert`.

Then, in your environment config file, let Paperclip know to look there by adding that 
directory to its path.

In development mode, you might add this line to `config/environments/development.rb)`:

    Paperclip.options[:command_path] = "/usr/local/bin/"

Installation
------------
as a gem:
  gem 'paperclip-youtube', :require => 'paperclip'

as a plugin:

  ruby script/plugin install git://github.com/dr-click/paperclip.git

Quick Start
-----------

In your model:

    class User < ActiveRecord::Base
	YOUTUBE_CONFIG = {:login_name=>Your_Login_Name,
						:login_password=>Your_Login_Password,
						:youttube_username=>Your_Youtube_Username,
						:developer_key=>Developer_Key}
	has_attached_file :video,
                    :storage=>:youtube,  
                    :youtube_options=>YOUTUBE_CONFIG,
                    :url=> ':youtube_url'
    end

In your migrations:

    class AddVideoColumnsToUser < ActiveRecord::Migration
      def self.up
        add_column :users, :video_file_name,    :string
        add_column :users, :video_content_type, :string
        add_column :users, :video_file_size,    :integer
        add_column :users, :video_updated_at,   :datetime
	add_column :users, :youtube_id,   :string
      end

      def self.down
        remove_column :users, :video_file_name
        remove_column :users, :video_content_type
        remove_column :users, :video_file_size
        remove_column :users, :video_updated_at
	remove_column :users, :youtube_id
      end
    end

In your edit and new views:

    <% form_for :user, @user, :url => user_path, :html => { :multipart => true } do |form| %>
      <%= form.file_field :video %>
    <% end %>

In your controller:

    def create
      @user = User.create( params[:user] )
    end

In your show view, this will return the thumbnail image:
    <%= image_tag @user.video.url(:thumbnail) %>

And you can return the video url, to use in the object tag:
    <%= @user.video.url %>


Credits
-------

The credits of the Youtube integration for Dr-Click : 
![Dr-Click](https://secure.gravatar.com/avatar/56d23c8d7784cbc3804f03f9465d99c0?s=140&d=https://d3nwyuy0nl342s.cloudfront.net%2Fimages%2Fgravatars%2Fgravatar-140.png)

