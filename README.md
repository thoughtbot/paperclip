# Paperclip [![Build Status](https://secure.travis-ci.org/thoughtbot/paperclip.png?branch=master)](http://travis-ci.org/thoughtbot/paperclip)

Paperclip is intended as an easy file attachment library for ActiveRecord. The
intent behind it was to keep setup as easy as possible and to treat files as
much like other attributes as possible. This means they aren't saved to their
final locations on disk, nor are they deleted if set to nil, until
ActiveRecord::Base#save is called. It manages validations based on size and
presence, if required. It can transform its assigned image into thumbnails if
needed, and the prerequisites are as simple as installing ImageMagick (which,
for most modern Unix-based systems, is as easy as installing the right
packages). Attached files are saved to the filesystem and referenced in the
browser by an easily understandable specification, which has sensible and
useful defaults.

See the documentation for `has_attached_file` in Paperclip::ClassMethods for
more detailed options.

The complete [RDoc](http://rdoc.info/gems/paperclip) is online.

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

If you're on Mac OSX, you'll want to run the following with Homebrew:

    brew install imagemagick

If you are dealing with pdf uploads or running the test suite, also run:

    brew install gs

Installation
------------

Paperclip is distributed as a gem, which is how it should be used in your app. It's
technically still installable as a plugin, but that's discouraged, as Rails plays
well with gems.

Include the gem in your Gemfile:

    gem "paperclip", "~> 2.4"

Or, if you don't use Bundler (though you probably should, even in Rails 2), with config.gem

    # In config/environment.rb
    ...
    Rails::Initializer.run do |config|
      ...
      config.gem "paperclip", :version => "~> 2.4"
      ...
    end
For Non-Rails usage:

    class ModuleName < ActiveRecord::Base
        include Paperclip::Glue
        ...
    end

Quick Start
-----------

In your model:

    class User < ActiveRecord::Base
      has_attached_file :avatar, :styles => { :medium => "300x300>", :thumb => "100x100>" }
    end

In your migrations:

    class AddAvatarColumnsToUser < ActiveRecord::Migration
      def self.up
        add_column :users, :avatar_file_name,    :string
        add_column :users, :avatar_content_type, :string
        add_column :users, :avatar_file_size,    :integer
        add_column :users, :avatar_updated_at,   :datetime
      end

      def self.down
        remove_column :users, :avatar_file_name
        remove_column :users, :avatar_content_type
        remove_column :users, :avatar_file_size
        remove_column :users, :avatar_updated_at
      end
    end

In your edit and new views:

    <%= form_for :user, @user, :url => user_path, :html => { :multipart => true } do |form| %>
      <%= form.file_field :avatar %>
    <% end %>

In your controller:

    def create
      @user = User.create( params[:user] )
    end

In your show view:

    <%= image_tag @user.avatar.url %>
    <%= image_tag @user.avatar.url(:medium) %>
    <%= image_tag @user.avatar.url(:thumb) %>

To detach a file, simply set the attribute to `nil`:

    @user.avatar = nil
    @user.save

Usage
-----

The basics of paperclip are quite simple: Declare that your model has an
attachment with the has_attached_file method, and give it a name. Paperclip
will wrap up up to four attributes (all prefixed with that attachment's name,
so you can have multiple attachments per model if you wish) and give them a
friendly front end. The attributes are `<attachment>_file_name`,
`<attachment>_file_size`, `<attachment>_content_type`, and `<attachment>_updated_at`.
Only `<attachment>_file_name` is required for paperclip to operate. More
information about the options to has_attached_file is available in the
documentation of Paperclip::ClassMethods.

Attachments can be validated with Paperclip's validation methods,
validates_attachment_presence, validates_attachment_content_type, and
validates_attachment_size.

Storage
-------

The files that are assigned as attachments are, by default, placed in the
directory specified by the :path option to has_attached_file. By default, this
location is ":rails_root/public/system/:attachment/:id/:style/:filename". This
location was chosen because on standard Capistrano deployments, the
public/system directory is symlinked to the app's shared directory, meaning it
will survive between deployments. For example, using that :path, you may have a
file at

    /data/myapp/releases/20081229172410/public/system/avatars/13/small/my_pic.png

_NOTE: This is a change from previous versions of Paperclip, but is overall a
safer choice for the default file store._

You may also choose to store your files using Amazon's S3 service. You can find
more information about S3 storage at the description for
Paperclip::Storage::S3.

Files on the local filesystem (and in the Rails app's public directory) will be
available to the internet at large. If you require access control, it's
possible to place your files in a different location. You will need to change
both the :path and :url options in order to make sure the files are unavailable
to the public. Both :path and :url allow the same set of interpolated
variables.

Post Processing
---------------

Paperclip supports an extensible selection of post-processors. When you define
a set of styles for an attachment, by default it is expected that those
"styles" are actually "thumbnails". However, you can do much more than just
thumbnail images. By defining a subclass of Paperclip::Processor, you can
perform any processing you want on the files that are attached. Any file in
your Rails app's lib/paperclip_processors directory is automatically loaded by
paperclip, allowing you to easily define custom processors. You can specify a
processor with the :processors option to has_attached_file:

    has_attached_file :scan, :styles => { :text => { :quality => :better } },
                             :processors => [:ocr]

This would load the hypothetical class Paperclip::Ocr, which would have the
hash "{ :quality => :better }" passed to it along with the uploaded file. For
more information about defining processors, see Paperclip::Processor.

The default processor is Paperclip::Thumbnail. For backwards compatability
reasons, you can pass a single geometry string or an array containing a
geometry and a format, which the file will be converted to, like so:

    has_attached_file :avatar, :styles => { :thumb => ["32x32#", :png] }

This will convert the "thumb" style to a 32x32 square in png format, regardless
of what was uploaded. If the format is not specified, it is kept the same (i.e.
jpgs will remain jpgs).

Multiple processors can be specified, and they will be invoked in the order
they are defined in the :processors array. Each successive processor will
be given the result of the previous processor's execution. All processors will
receive the same parameters, which are what you define in the :styles hash.
For example, assuming we had this definition:

    has_attached_file :scan, :styles => { :text => { :quality => :better } },
                             :processors => [:rotator, :ocr]

then both the :rotator processor and the :ocr processor would receive the
options "{ :quality => :better }". This parameter may not mean anything to one
or more or the processors, and they are expected to ignore it.

_NOTE: Because processors operate by turning the original attachment into the
styles, no processors will be run if there are no styles defined._

If you're interested in caching your thumbnail's width, height and size in the
database, take a look at the [paperclip-meta](https://github.com/y8/paperclip-meta) gem.

Also, if you're interested in generating the thumbnail on-the-fly, you might want
to look into the [attachment_on_the_fly](https://github.com/drpentode/Attachment-on-the-Fly) gem.

Events
------

Before and after the Post Processing step, Paperclip calls back to the model
with a few callbacks, allowing the model to change or cancel the processing
step. The callbacks are `before_post_process` and `after_post_process` (which
are called before and after the processing of each attachment), and the
attachment-specific `before_<attachment>_post_process` and
`after_<attachment>_post_process`. The callbacks are intended to be as close to
normal ActiveRecord callbacks as possible, so if you return false (specifically
- returning nil is not the same) in a before_ filter, the post processing step
will halt. Returning false in an after_ filter will not halt anything, but you
can access the model and the attachment if necessary.

_NOTE: Post processing will not even *start* if the attachment is not valid
according to the validations. Your callbacks and processors will *only* be
called with valid attachments._

URI Obfuscation
---------------

Paperclip has an interpolation called `:hash` for obfuscating filenames of
publicly-available files.

Example Usage:

    has_attached_file :avatar, {
        :url => "/system/:hash.:extension",
        :hash_secret => "longSecretString"
    }


The `:hash` interpolation will be replaced with a unique hash made up of whatever
is specified in `:hash_data`. The default value for `:hash_data` is `":class/:attachment/:id/:style/:updated_at"`.

`:hash_secret` is required, an exception will be raised if `:hash` is used without `:hash_secret` present.

For more on this feature read the author's own explanation. [https://github.com/thoughtbot/paperclip/pull/416](https://github.com/thoughtbot/paperclip/pull/416)

MD5 Checksum / Fingerprint
-------

A MD5 checksum of the original file assigned will be placed in the model if it
has an attribute named fingerprint.  Following the user model migration example
above, the migration would look like the following.

    class AddAvatarFingerprintColumnToUser < ActiveRecord::Migration
      def self.up
        add_column :users, :avatar_fingerprint, :string
      end

      def self.down
        remove_column :users, :avatar_fingerprint
      end
    end

Custom Attachment Processors
-------

Custom attachment processors can be implemented and their only requirement is
to inherit from `Paperclip::Processor` (see `lib/paperclip/processor.rb`).
For example, when `:styles` are specified for an image attachment, the
thumbnail processor (see `lib/paperclip/thumbnail.rb`) is loaded without having
to specify it as a `:processor` parameter to `has_attached_file`.  When any
other processor is defined it must be called out in the `:processors`
parameter if it is to be applied to the attachment.  The thumbnail processor
uses the imagemagick `convert` command to do the work of resizing image
thumbnails.  It would be easy to create a custom processor that watermarks
an image using imagemagick's `composite` command.  Following the
implementation pattern of the thumbnail processor would be a way to implement a
watermark processor.  All kinds of attachment processors can be created;
a few utility examples would be compression and encryption processors.


Dynamic Configuration
---------------------

Callable objects (lambdas, Procs) can be used in a number of places for dynamic
configuration throughout Paperclip.  This strategy exists in a number of
components of the library but is most significant in the possibilities for
allowing custom styles and processors to be applied for specific model
instances, rather than applying defined styles and processors across all
instances.

Dynamic Styles:

Imagine a user model that had different styles based on the role of the user.
Perhaps some users are bosses (e.g. a User model instance responds to #boss?)
and merit a bigger avatar thumbnail than regular users. The configuration to
determine what style parameters are to be used based on the user role might
look as follows where a boss will receive a `300x300` thumbnail otherwise a
`100x100` thumbnail will be created.

    class User < ActiveRecord::Base
      has_attached_file :avatar, :styles => lambda { |attachment| { :thumb => (attachment.instance.boss? ? "300x300>" : "100x100>") }
    end

Dynamic Processors:

Another contrived example is a user model that is aware of which file processors
should be applied to it (beyond the implied `thumbnail` processor invoked when
`:styles` are defined). Perhaps we have a watermark processor available and it is
only used on the avatars of certain models.  The configuration for this might be
where the instance is queried for which processors should be applied to it.
Presumably some users might return `[:thumbnail, :watermark]` for its
processors, where a defined `watermark` processor is invoked after the
`thumbnail` processor already defined by Paperclip.

    class User < ActiveRecord::Base
      has_attached_file :avatar, :processors => lambda { |instance| instance.processors }
      attr_accessor :watermark
    end

Deploy
------

Paperclip is aware of new attachment styles you have added in previous deploy. The only thing you should do after each deployment is to call
`rake paperclip:refresh:missing_styles`.  It will store current attachment styles in `RAILS_ROOT/public/system/paperclip_attachments.yml`
by default. You can change it by:

    Paperclip.registered_attachments_styles_path = '/tmp/config/paperclip_attachments.yml'

Here is an example for Capistrano:

    namespace :deploy do
      desc "build missing paperclip styles"
      task :build_missing_paperclip_styles, :roles => :app do
        run "cd #{release_path}; RAILS_ENV=production bundle exec rake paperclip:refresh:missing_styles"
      end
    end

    after("deploy:update_code", "deploy:build_missing_paperclip_styles")

Now you don't have to remember to refresh thumbnails in production everytime you add new style.
Unfortunately it does not work with dynamic styles - it just ignores them.

If you already have working app and don't want `rake paperclip:refresh:missing_styles` to refresh old pictures, you need to tell
Paperclip about existing styles. Simply create paperclip_attachments.yml file by hand. For example:

    class User < ActiveRecord::Base
      has_attached_file :avatar, :styles => {:thumb => 'x100', :croppable => '600x600>', :big => '1000x1000>'}
    end

    class Book < ActiveRecord::Base
      has_attached_file :cover, :styles => {:small => 'x100', :large => '1000x1000>'}
      has_attached_file :sample, :styles => {:thumb => 'x100'}
    end

Then in `RAILS_ROOT/public/system/paperclip_attachments.yml`:

    ---
    :User:
      :avatar:
      - :thumb
      - :croppable
      - :big
    :Book:
      :cover:
      - :small
      - :large
      :sample:
      - :thumb

Testing
-------

Paperclip provides rspec-compatible matchers for testing attachments. See the
documentation on [Paperclip::Shoulda::Matchers](http://rubydoc.info/gems/paperclip/Paperclip/Shoulda/Matchers)
for more information.

Contributing
------------

If you'd like to contribute a feature or bugfix: Thanks! To make sure your
fix/feature has a high chance of being included, please read the following
guidelines:

1. Ask on the mailing list[http://groups.google.com/group/paperclip-plugin], or
   post a new GitHub Issue[http://github.com/thoughtbot/paperclip/issues].
2. Make sure there are tests! We will not accept any patch that is not tested.
   It's a rare time when explicit tests aren't needed. If you have questions
   about writing tests for paperclip, please ask the mailing list.

Please see CONTRIBUTING.md for details.

Credits
-------

![thoughtbot](http://thoughtbot.com/images/tm/logo.png)

Paperclip is maintained and funded by [thoughtbot, inc](http://thoughtbot.com/community)

Thank you to all [the contributors](https://github.com/thoughtbot/paperclip/contributors)!

The names and logos for thoughtbot are trademarks of thoughtbot, inc.

License
-------

Paperclip is Copyright © 2008-2011 thoughtbot. It is free software, and may be redistributed under the terms specified in the MIT-LICENSE file.
