Paperclip
=========

[![Build Status](https://secure.travis-ci.org/thoughtbot/paperclip.png?branch=master)](http://travis-ci.org/thoughtbot/paperclip) [![Dependency Status](https://gemnasium.com/thoughtbot/paperclip.png?travis)](https://gemnasium.com/thoughtbot/paperclip) [![Code Climate](https://codeclimate.com/github/thoughtbot/paperclip.png)](https://codeclimate.com/github/thoughtbot/paperclip) [![Inline docs](http://inch-pages.github.io/github/thoughtbot/paperclip.png)](http://inch-pages.github.io/github/thoughtbot/paperclip)

Paperclip is intended as an easy file attachment library for Active Record. The
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

See the documentation for `has_attached_file` in [`Paperclip::ClassMethods`](http://rubydoc.info/gems/paperclip/Paperclip/ClassMethods) for
more detailed options.

The complete [RDoc](http://rdoc.info/gems/paperclip) is online.


Requirements
------------

### Ruby and Rails

Paperclip now requires Ruby version **>= 1.9.2** and Rails version **>= 3.0** (Only if you're going to use Paperclip with Ruby on Rails.)

If you're still on Ruby 1.8.7 or Ruby on Rails 2.3.x, you can still use Paperclip 2.7.x with your project. Also, everything in this README might not apply to your version of Paperclip, and you should read [the README for version 2.7](http://rubydoc.info/gems/paperclip/2.7.0) instead.

### Image Processor

[ImageMagick](http://www.imagemagick.org) must be installed and Paperclip must have access to it. To ensure
that it does, on your command line, run `which convert` (one of the ImageMagick
utilities). This will give you the path where that utility is installed. For
example, it might return `/usr/local/bin/convert`.

Then, in your environment config file, let Paperclip know to look there by adding that
directory to its path.

In development mode, you might add this line to `config/environments/development.rb)`:

```ruby
Paperclip.options[:command_path] = "/usr/local/bin/"
```

If you're on Mac OS X, you'll want to run the following with Homebrew:

    brew install imagemagick

If you are dealing with pdf uploads or running the test suite, you'll also need
GhostScript to be installed. On Mac OS X, you can also install that using Homebrew:

    brew install gs

### `file` command

The Unix [`file` command](http://en.wikipedia.org/wiki/File_(command)) is required for content type checking.
This utility isn't available in Windows, but comes bundled with Ruby [Devkit](https://github.com/oneclick/rubyinstaller/wiki/Development-Kit), 
so Windows users must make sure that the devkit is installed and added to system `PATH`.

Installation
------------

Paperclip is distributed as a gem, which is how it should be used in your app.

Include the gem in your Gemfile:

```ruby
gem "paperclip", "~> 4.1"
```

If you're still using Rails 2.3.x, you should do this instead:

```ruby
gem "paperclip", "~> 2.7"
```

Or, if you want to get the latest, you can get master from the main paperclip repository:

```ruby
gem "paperclip", :git => "git://github.com/thoughtbot/paperclip.git"
```

If you're trying to use features that don't seem to be in the latest released gem, but are
mentioned in this README, then you probably need to specify the master branch if you want to
use them. This README is probably ahead of the latest released version, if you're reading it
on GitHub.

For Non-Rails usage:

```ruby
class ModuleName < ActiveRecord::Base
  include Paperclip::Glue
  ...
end
```

Quick Start
-----------

### Models

**Rails 3**

```ruby
class User < ActiveRecord::Base
  attr_accessible :avatar
  has_attached_file :avatar, :styles => { :medium => "300x300>", :thumb => "100x100>" }, :default_url => "/images/:style/missing.png"
  validates_attachment_content_type :avatar, :content_type => /\Aimage\/.*\Z/
end
```

**Rails 4**

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar, :styles => { :medium => "300x300>", :thumb => "100x100>" }, :default_url => "/images/:style/missing.png"
  validates_attachment_content_type :avatar, :content_type => /\Aimage\/.*\Z/
end
```

### Migrations

```ruby
class AddAvatarColumnsToUsers < ActiveRecord::Migration
  def self.up
    add_attachment :users, :avatar
  end

  def self.down
    remove_attachment :users, :avatar
  end
end
```

(Or you can use migration generator: `rails generate paperclip user avatar`)

### Edit and New Views

```erb
<%= form_for @user, :url => users_path, :html => { :multipart => true } do |form| %>
  <%= form.file_field :avatar %>
<% end %>
```

### Controller

**Rails 3**

```ruby
def create
  @user = User.create( params[:user] )
end
```

**Rails 4**

```ruby
def create
  @user = User.create( user_params )
end

private

# Use strong_parameters for attribute whitelisting
# Be sure to update your create() and update() controller methods.

def user_params
  params.require(:user).permit(:avatar)
end
```

### Show View

```erb
<%= image_tag @user.avatar.url %>
<%= image_tag @user.avatar.url(:medium) %>
<%= image_tag @user.avatar.url(:thumb) %>
```

### Deleting an Attachment

Set the attribute to `nil` and save.

```ruby
@user.avatar = nil
@user.save
```

Usage
-----

The basics of paperclip are quite simple: Declare that your model has an
attachment with the `has_attached_file` method, and give it a name.

Paperclip will wrap up to four attributes (all prefixed with that attachment's name,
so you can have multiple attachments per model if you wish) and give them a
friendly front end. These attributes are:

* `<attachment>_file_name`
* `<attachment>_file_size`
* `<attachment>_content_type`
* `<attachment>_updated_at`

By default, only `<attachment>_file_name` is required for paperclip to operate.
You'll need to add `<attachment>_content_type` in case you want to use content type
validation.

More information about the options to `has_attached_file` is available in the
documentation of [`Paperclip::ClassMethods`](http://rubydoc.info/gems/paperclip/Paperclip/ClassMethods).

Validations
-----------

For validations, Paperclip introduces several validators to validate your attachment:

* `AttachmentContentTypeValidator`
* `AttachmentPresenceValidator`
* `AttachmentSizeValidator`

Example Usage:

```ruby
validates :avatar, :attachment_presence => true
validates_with AttachmentPresenceValidator, :attributes => :avatar
```

Validators can also be defined using the old helper style:

* `validates_attachment_presence`
* `validates_attachment_content_type`
* `validates_attachment_size`

Example Usage:

```ruby
validates_attachment_presence :avatar
```

Lastly, you can also define multiple validations on a single attachment using `validates_attachment`:

```ruby
validates_attachment :avatar, :presence => true,
  :content_type => { :content_type => "image/jpeg" },
  :size => { :in => 0..10.kilobytes }
```

_NOTE: Post processing will not even *start* if the attachment is not valid
according to the validations. Your callbacks and processors will *only* be
called with valid attachments._

```ruby
class Message < ActiveRecord::Base
  has_attached_file :asset, styles: {thumb: "100x100#"}

  before_post_process :skip_for_audio

  def skip_for_audio
    ! %w(audio/ogg application/ogg).include?(asset_content_type)
  end
end
```

If you have other validations that depend on assignment order, the recommended
course of action is to prevent the assignment of the attachment until
afterwards, then assign manually:

```ruby
class Book < ActiveRecord::Base
  has_attached_file :document, styles: {thumbnail: "60x60#"}
  validates_attachment :document, content_type: { content_type: "application/pdf" }
  validates_something_else # Other validations that conflict with Paperclip's
end

class BooksController < ApplicationController
  def create
    @book = Book.new(book_params)
    @book.document = params[:book][:document]
    @book.save
    respond_with @book
  end

  private

  def book_params
    params.require(:book).permit(:title, :author)
  end
end
```

**A note on content_type validations and security**

You should ensure that you validate files to be only those MIME types you
explicitly want to support.  If you don't, you could be open to
<a href="https://www.owasp.org/index.php/Testing_for_Stored_Cross_site_scripting_(OWASP-DV-002)">XSS attacks</a>
if a user uploads a file with a malicious HTML payload.

If you're only interested in images, restrict your allowed content_types to
image-y ones:

```ruby
validates_attachment :avatar,
  :content_type => { :content_type => ["image/jpeg", "image/gif", "image/png"] }
```

`Paperclip::ContentTypeDetector` will attempt to match a file's extension to an
inferred content_type, regardless of the actual contents of the file.

Security Validations
====================

Thanks to a report from [Egor Homakov](http://homakov.blogspot.com/) we have
taken steps to prevent people from spoofing Content-Types and getting data
you weren't expecting onto your server.

NOTE: Starting at version 4.0.0, all attachments are *required* to include a
content_type validation, a file_name validation, or to explicitly state that
they're not going to have either. *Paperclip will raise an error* if you do not
do this.

```ruby
class ActiveRecord::Base
  has_attached_file :avatar
# Validate content type
  validates_attachment_content_type :avatar, :content_type => /\Aimage/
# Validate filename
  validates_attachment_file_name :avatar, :matches => [/png\Z/, /jpe?g\Z/]
# Explicitly do not validate
  do_not_validate_attachment_file_type :avatar
end
```

This keeps Paperclip secure-by-default, and will prevent people trying to mess
with your filesystem.

NOTE: Also starting at version 4.0.0, Paperclip has another validation that
cannot be turned off. This validation will prevent content type spoofing. That
is, uploading a PHP document (for example) as part of the EXIF tags of a
well-formed JPEG. This check is limited to the media type (the first part of the
MIME type, so, 'text' in 'text/plain'). This will prevent HTML documents from
being uploaded as JPEGs, but will not prevent GIFs from being uploaded with a
.jpg extension. This validation will only add validation errors to the form. It
will not cause Errors to be raised.

Defaults
--------
Global defaults for all your paperclip attachments can be defined by changing the Paperclip::Attachment.default_options Hash, this can be useful for setting your default storage settings per example so you won't have to define them in every has_attached_file definition.

If you're using Rails you can define a Hash with default options in config/application.rb or in any of the config/environments/*.rb files on config.paperclip_defaults, these will get merged into Paperclip::Attachment.default_options as your Rails app boots. An example:

```ruby
module YourApp
  class Application < Rails::Application
    # Other code...

    config.paperclip_defaults = {:storage => :fog, :fog_credentials => {:provider => "Local", :local_root => "#{Rails.root}/public"}, :fog_directory => "", :fog_host => "localhost"}
  end
end
```

Another option is to directly modify the Paperclip::Attachment.default_options Hash, this method works for non-Rails applications or is an option if you prefer to place the Paperclip default settings in an initializer.

An example Rails initializer would look something like this:

```ruby
Paperclip::Attachment.default_options[:storage] = :fog
Paperclip::Attachment.default_options[:fog_credentials] = {:provider => "Local", :local_root => "#{Rails.root}/public"}
Paperclip::Attachment.default_options[:fog_directory] = ""
Paperclip::Attachment.default_options[:fog_host] = "http://localhost:3000"
```

Migrations
----------

Paperclip defines several migration methods which can be used to create necessary columns in your
model. There are two types of method:

### Table Definition

```ruby
class AddAttachmentToUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.attachment :avatar
    end
  end
end
```

If you're using Rails 3.2 or newer, this method works in `change` method as well:

```ruby
class AddAttachmentToUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.attachment :avatar
    end
  end
end
```

### Schema Definition

```ruby
class AddAttachmentToUsers < ActiveRecord::Migration
  def self.up
    add_attachment :users, :avatar
  end

  def self.down
    remove_attachment :users, :avatar
  end
end
```

If you're using Rails 3.2 or newer, you only need `add_attachment` in your `change` method:

```ruby
class AddAttachmentToUsers < ActiveRecord::Migration
  def change
    add_attachment :users, :avatar
  end
end
```

### Vintage syntax

Vintage syntax (such as `t.has_attached_file` and `drop_attached_file`) are still supported in
Paperclip 3.x, but you're advised to update those migration files to use this new syntax.

Storage
-------

Paperclip ships with 3 storage adapters:

* File Storage
* S3 Storage (via `aws-sdk`)
* Fog Storage

If you would like to use Paperclip with another storage, you can install these
gems along side with Paperclip:

* [paperclip-azure-storage](https://github.com/gmontard/paperclip-azure-storage)
* [paperclip-dropbox](https://github.com/janko-m/paperclip-dropbox)

### Understanding Storage

The files that are assigned as attachments are, by default, placed in the
directory specified by the `:path` option to `has_attached_file`. By default, this
location is `:rails_root/public/system/:class/:attachment/:id_partition/:style/:filename`.
This location was chosen because on standard Capistrano deployments, the
`public/system` directory is symlinked to the app's shared directory, meaning it
will survive between deployments. For example, using that `:path`, you may have a
file at

    /data/myapp/releases/20081229172410/public/system/users/avatar/000/000/013/small/my_pic.png

_**NOTE**: This is a change from previous versions of Paperclip, but is overall a
safer choice for the default file store._

You may also choose to store your files using Amazon's S3 service. To do so, include
the `aws-sdk` gem in your Gemfile:

```ruby
gem 'aws-sdk', '~> 1.5.7'
```

And then you can specify using S3 from `has_attached_file`.
You can find more information about configuring and using S3 storage in
[the `Paperclip::Storage::S3` documentation](http://rubydoc.info/gems/paperclip/Paperclip/Storage/S3).

Files on the local filesystem (and in the Rails app's public directory) will be
available to the internet at large. If you require access control, it's
possible to place your files in a different location. You will need to change
both the `:path` and `:url` options in order to make sure the files are unavailable
to the public. Both `:path` and `:url` allow the same set of interpolated
variables.

Post Processing
---------------

Paperclip supports an extensible selection of post-processors. When you define
a set of styles for an attachment, by default it is expected that those
"styles" are actually "thumbnails". However, you can do much more than just
thumbnail images. By defining a subclass of Paperclip::Processor, you can
perform any processing you want on the files that are attached. Any file in
your Rails app's lib/paperclip\_processors directory is automatically loaded by
paperclip, allowing you to easily define custom processors. You can specify a
processor with the :processors option to `has_attached_file`:

```ruby
has_attached_file :scan, :styles => { :text => { :quality => :better } },
                         :processors => [:ocr]
```

This would load the hypothetical class Paperclip::Ocr, which would have the
hash "{ :quality => :better }" passed to it along with the uploaded file. For
more information about defining processors, see Paperclip::Processor.

The default processor is Paperclip::Thumbnail. For backwards compatibility
reasons, you can pass a single geometry string or an array containing a
geometry and a format, which the file will be converted to, like so:

```ruby
has_attached_file :avatar, :styles => { :thumb => ["32x32#", :png] }
```

This will convert the "thumb" style to a 32x32 square in png format, regardless
of what was uploaded. If the format is not specified, it is kept the same (i.e.
jpgs will remain jpgs). For more information on the accepted style formats, see
[here](http://www.imagemagick.org/script/command-line-processing.php#geometry).

Multiple processors can be specified, and they will be invoked in the order
they are defined in the :processors array. Each successive processor will
be given the result of the previous processor's execution. All processors will
receive the same parameters, which are what you define in the :styles hash.
For example, assuming we had this definition:

```ruby
has_attached_file :scan, :styles => { :text => { :quality => :better } },
                         :processors => [:rotator, :ocr]
```

then both the :rotator processor and the :ocr processor would receive the
options "{ :quality => :better }". This parameter may not mean anything to one
or more or the processors, and they are expected to ignore it.

_NOTE: Because processors operate by turning the original attachment into the
styles, no processors will be run if there are no styles defined._

If you're interested in caching your thumbnail's width, height and size in the
database, take a look at the [paperclip-meta](https://github.com/teeparham/paperclip-meta) gem.

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
\- returning nil is not the same) in a `before_filter`, the post processing step
will halt. Returning false in an `after_filter` will not halt anything, but you
can access the model and the attachment if necessary.

_NOTE: Post processing will not even *start* if the attachment is not valid
according to the validations. Your callbacks and processors will *only* be
called with valid attachments._

```ruby
class Message < ActiveRecord::Base
  has_attached_file :asset, styles: {thumb: "100x100#"}

  before_post_process :skip_for_audio

  def skip_for_audio
    ! %w(audio/ogg application/ogg).include?(asset_content_type)
  end
end
```

URI Obfuscation
---------------

Paperclip has an interpolation called `:hash` for obfuscating filenames of
publicly-available files.

Example Usage:

```ruby
has_attached_file :avatar, {
    :url => "/system/:hash.:extension",
    :hash_secret => "longSecretString"
}
```


The `:hash` interpolation will be replaced with a unique hash made up of whatever
is specified in `:hash_data`. The default value for `:hash_data` is `":class/:attachment/:id/:style/:updated_at"`.

`:hash_secret` is required, an exception will be raised if `:hash` is used without `:hash_secret` present.

For more on this feature read the author's own explanation. [https://github.com/thoughtbot/paperclip/pull/416](https://github.com/thoughtbot/paperclip/pull/416)

MD5 Checksum / Fingerprint
-------

A MD5 checksum of the original file assigned will be placed in the model if it
has an attribute named fingerprint.  Following the user model migration example
above, the migration would look like the following.

```ruby
class AddAvatarFingerprintColumnToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :avatar_fingerprint, :string
  end

  def self.down
    remove_column :users, :avatar_fingerprint
  end
end
```

File Preservation for Soft-Delete
-------

An option is available to preserve attachments in order to play nicely with soft-deleted models. (acts_as_paranoid, paranoia, etc.)

```ruby
has_attached_file :some_attachment, {
    :preserve_files => "true",
}
```

This will prevent ```some_attachment``` from being wiped out when the model gets destroyed, so it will still exist when the object is restored later.

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

### Dynamic Styles:

Imagine a user model that had different styles based on the role of the user.
Perhaps some users are bosses (e.g. a User model instance responds to #boss?)
and merit a bigger avatar thumbnail than regular users. The configuration to
determine what style parameters are to be used based on the user role might
look as follows where a boss will receive a `300x300` thumbnail otherwise a
`100x100` thumbnail will be created.

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar, :styles => lambda { |attachment| { :thumb => (attachment.instance.boss? ? "300x300>" : "100x100>") } }
end
```

### Dynamic Processors:

Another contrived example is a user model that is aware of which file processors
should be applied to it (beyond the implied `thumbnail` processor invoked when
`:styles` are defined). Perhaps we have a watermark processor available and it is
only used on the avatars of certain models.  The configuration for this might be
where the instance is queried for which processors should be applied to it.
Presumably some users might return `[:thumbnail, :watermark]` for its
processors, where a defined `watermark` processor is invoked after the
`thumbnail` processor already defined by Paperclip.

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar, :processors => lambda { |instance| instance.processors }
  attr_accessor :watermark
end
```

Logging
----------

By default Paperclip outputs logging according to your logger level. If you want to disable logging (e.g. during testing) add this in to your environment's configuration:
```ruby
Your::Application.configure do
...
  Paperclip.options[:log] = false
...
end
```

More information in the [rdocs](http://rdoc.info/github/thoughtbot/paperclip/Paperclip.options)

Deployment
----------

Paperclip is aware of new attachment styles you have added in previous deploys. The only thing you should do after each deployment is to call
`rake paperclip:refresh:missing_styles`.  It will store current attachment styles in `RAILS_ROOT/public/system/paperclip_attachments.yml`
by default. You can change it by:

```ruby
Paperclip.registered_attachments_styles_path = '/tmp/config/paperclip_attachments.yml'
```

Here is an example for Capistrano:

```ruby
namespace :deploy do
  desc "build missing paperclip styles"
  task :build_missing_paperclip_styles do
    on roles(:app) do
      execute "cd #{current_path}; RAILS_ENV=production bundle exec rake paperclip:refresh:missing_styles"
    end
  end
end

after("deploy:compile_assets", "deploy:build_missing_paperclip_styles")
```

Now you don't have to remember to refresh thumbnails in production every time you add a new style.
Unfortunately it does not work with dynamic styles - it just ignores them.

If you already have a working app and don't want `rake paperclip:refresh:missing_styles` to refresh old pictures, you need to tell
Paperclip about existing styles. Simply create a `paperclip_attachments.yml` file by hand. For example:

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar, :styles => {:thumb => 'x100', :croppable => '600x600>', :big => '1000x1000>'}
end

class Book < ActiveRecord::Base
  has_attached_file :cover, :styles => {:small => 'x100', :large => '1000x1000>'}
  has_attached_file :sample, :styles => {:thumb => 'x100'}
end
```

Then in `RAILS_ROOT/public/system/paperclip_attachments.yml`:

```yml
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
```

Testing
-------

Paperclip provides rspec-compatible matchers for testing attachments. See the
documentation on [Paperclip::Shoulda::Matchers](http://rubydoc.info/gems/paperclip/Paperclip/Shoulda/Matchers)
for more information.

**Parallel Tests**

Because of the default `path` for Paperclip storage, if you try to run tests in
parallel, you may find that files get overwritten because the same path is being
calculated for them in each test process. While this fix works for
parallel_tests, a similar concept should be used for any other mechanism for
running tests concurrently.

```ruby
if ENV['PARALLEL_TEST_GROUPS']
  Paperclip::Attachment.default_options[:path] = ":rails_root/public/system/:rails_env/#{ENV['TEST_ENV_NUMBER'].to_i}/:class/:attachment/:id_partition/:filename"
else
  Paperclip::Attachment.default_options[:path] = ":rails_root/public/system/:rails_env/:class/:attachment/:id_partition/:filename"
end
```

The important part here being the inclusion of `ENV['TEST_ENV_NUMBER']`, or the
similar mechanism for whichever parallel testing library you use.

Contributing
------------

If you'd like to contribute a feature or bugfix: Thanks! To make sure your
fix/feature has a high chance of being included, please read the following
guidelines:

1. Post a [pull request](https://github.com/thoughtbot/paperclip/compare/).
2. Make sure there are tests! We will not accept any patch that is not tested.
   It's a rare time when explicit tests aren't needed. If you have questions
   about writing tests for paperclip, please open a
   [GitHub issue](https://github.com/thoughtbot/paperclip/issues/new).

Please see `CONTRIBUTING.md` for more details on contributing and running test.

Credits
-------

![thoughtbot](http://thoughtbot.com/logo.png)

Paperclip is maintained and funded by [thoughtbot, inc](http://thoughtbot.com/community)

Thank you to all [the contributors](https://github.com/thoughtbot/paperclip/contributors)!

The names and logos for thoughtbot are trademarks of thoughtbot, inc.

License
-------

Paperclip is Copyright © 2008-2014 thoughtbot, inc. It is free software, and may be
redistributed under the terms specified in the MIT-LICENSE file.
