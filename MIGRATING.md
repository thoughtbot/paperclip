# Migrating from Paperclip to ActiveStorage

Paperclip and ActiveStorage solve similar problems with similar solutions, so
transitioning from one to the other is straightforward data re-writing.

The process of going from Paperclip to ActiveStorage is as follows:

1. Apply the ActiveStorage database migrations.
2. Configure storage.
3. Copy the database data over.
4. Copy the files over.
5. Update your tests.
6. Update your views.
7. Update your controllers.
8. Update your models.

## Apply the ActiveStorage database migrations

Follow [the instructions for installing ActiveStorage]. You'll very likely want
to add the `mini_magick` gem to your Gemfile.

```sh
rails active_storage:install
```

[the instructions for installing ActiveStorage]: https://github.com/rails/rails/blob/master/activestorage/README.md#installation

## Configure storage

Again, follow [the instructions for configuring ActiveStorage].

[the instructions for configuring ActiveStorage]: http://edgeguides.rubyonrails.org/active_storage_overview.html#setup

## Copy the database data over

The `active_storage_blobs` and `active_storage_attachments` tables are where
ActiveStorage expects to find file metadata. Paperclip stores the file metadata
directly on the associated object's table.

You'll need to write a migration for this conversion. Because the models for
your domain are involved, it's tricky to supply a simple script. But we'll try!

Here's how it would go for a `User` with an `avatar`, that is this in
Paperclip:

```ruby
class User < ApplicationRecord
  has_attached_file :avatar
end
```

Your Paperclip migrations will produce a table like so:

```ruby
create_table "users", force: :cascade do |t|
  t.string "avatar_file_name"
  t.string "avatar_content_type"
  t.integer "avatar_file_size"
  t.datetime "avatar_updated_at"
end
```

And you'll be converting into these tables:

```ruby
create_table "active_storage_attachments", force: :cascade do |t|
  t.string "name", null: false
  t.string "record_type", null: false
  t.integer "record_id", null: false
  t.integer "blob_id", null: false
  t.datetime "created_at", null: false
  t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
  t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
end
```

```ruby
create_table "active_storage_blobs", force: :cascade do |t|
  t.string "key", null: false
  t.string "filename", null: false
  t.string "content_type"
  t.text "metadata"
  t.bigint "byte_size", null: false
  t.string "checksum", null: false
  t.datetime "created_at", null: false
  t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
end
```

So, assuming you want to leave the files in the exact same place,  _this is
your migration_. Otherwise, see the next section first and modify the migration
to taste.

```ruby
Dir[Rails.root.join("app/models/**/*.rb")].sort.each { |file| require file }

class ConvertToActiveStorage < ActiveRecord::Migration[5.2]
  require 'open-uri'

  def up
    # postgres
    get_blob_id = 'LASTVAL()'
    # mariadb
    # get_blob_id = 'LAST_INSERT_ID()'
    # sqlite
    # get_blob_id = 'LAST_INSERT_ROWID()'

    active_storage_blob_statement = ActiveRecord::Base.connection.raw_connection.prepare(<<-SQL)
      INSERT INTO active_storage_blobs (
        `key`, filename, content_type, metadata, byte_size, checksum, created_at
      ) VALUES (?, ?, ?, '{}', ?, ?, ?)
    SQL

    active_storage_attachment_statement = ActiveRecord::Base.connection.raw_connection.prepare(<<-SQL)
      INSERT INTO active_storage_attachments (
        name, record_type, record_id, blob_id, created_at
      ) VALUES (?, ?, ?, #{get_blob_id}, ?)
    SQL

    models = ActiveRecord::Base.descendants.reject(&:abstract_class?)

    transaction do
      models.each do |model|
        attachments = model.column_names.map do |c|
          if c =~ /(.+)_file_name$/
            $1
          end
        end.compact

        model.find_each.each do |instance|
          attachments.each do |attachment|
            active_storage_blob_statement.execute(
              key(instance, attachment),
              instance.send("#{attachment}_file_name"),
              instance.send("#{attachment}_content_type"),
              instance.send("#{attachment}_file_size"),
              checksum(instance.send(attachment)),
              instance.updated_at.iso8601
            )

            active_storage_attachment_statement.
              execute(attachment, model.name, instance.id, instance.updated_at.iso8601)
          end
        end
      end
    end

    active_storage_attachment_statement.close
    active_storage_blob_statement.close
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def key(instance, attachment)
    SecureRandom.uuid
    # Alternatively:
    # instance.send("#{attachment}_file_name")
  end

  def checksum(attachment)
    # local files stored on disk:
    url = attachment.path
    Digest::MD5.base64digest(File.read(url))

    # remote files stored on another person's computer:
    # url = attachment.url
    # Digest::MD5.base64digest(Net::HTTP.get(URI(url)))
  end
end
```

## Copy the files over

The above migration leaves the files as they are. However, the default
Paperclip and ActiveStorage storage services use different locations.

By default, Paperclip looks like this:

```
public/system/users/avatars/000/000/004/original/the-mystery-of-life.png
```

And ActiveStorage looks like this:

```
storage/xM/RX/xMRXuT6nqpoiConJFQJFt6c9
```

That `xMRXuT6nqpoiConJFQJFt6c9` is the `active_storage_blobs.key` value. In the
migration above we simply used the filename but you may wish to use a UUID
instead.


### Moving local storage files

```ruby
#!bin/rails runner

class ActiveStorageBlob < ActiveRecord::Base
end

class ActiveStorageAttachment < ActiveRecord::Base
  belongs_to :blob, class_name: 'ActiveStorageBlob'
  belongs_to :record, polymorphic: true
end

ActiveStorageAttachment.find_each do |attachment|
  name = attachment.name

  source = attachment.record.send(name).path
  dest_dir = File.join(
    "storage",
    attachment.blob.key.first(2),
    attachment.blob.key.first(4).last(2))
  dest = File.join(dest_dir, attachment.blob.key)

  FileUtils.mkdir_p(dest_dir)
  puts "Moving #{source} to #{dest}"
  FileUtils.cp(source, dest)
end
```

### Moving files on a remote host (S3, Azure Storage, GCS, etc.)

One of the most straightforward ways to move assets stored on a remote host is
to use a rake task that regenerates the file names and places them in the
proper file structure/hierarchy.

Assuming you have a model configured similarly to the example below:

```ruby
class Organization < ApplicationRecord
  # New ActiveStorage declaration
  has_one_attached :logo

  # Old Paperclip config
  # must be removed BEFORE to running the rake task so that
  # all of the new ActiveStorage goodness can be used when
  # calling organization.logo
  has_attached_file :logo,
                    path: "/organizations/:id/:basename_:style.:extension",
                    default_url: "https://s3.amazonaws.com/xxxxx/organizations/missing_:style.jpg",
                    default_style: :normal,
                    styles: { thumb: "64x64#", normal: "400x400>" },
                    convert_options: { thumb: "-quality 100 -strip", normal: "-quality 75 -strip" }
end
```

The following rake task would migrate all of your assets:

```ruby
namespace :organizations do
  task migrate_to_active_storage: :environment do
    Organization.where.not(logo_file_name: nil).find_each do |organization|
      # This step helps us catch any attachments we might have uploaded that
      # don't have an explicit file extension in the filename
      image = organization.logo_file_name
      ext = File.extname(image)
      image_original = URI.unescape(image.gsub(ext, "_original#{ext}"))

      # this url pattern can be changed to reflect whatever service you use
      logo_url = "https://s3.amazonaws.com/xxxxx/organizations/#{organization.id}/#{image_original}"
      organization.logo.attach(io: open(logo_url),
                                   filename: organization.logo_file_name,
                                   content_type: organization.logo_content_type)
    end
  end
end
```

An added advantage of this method is that you're creating a copy of all assets,
which is handy in the event you need to rollback your deploy.

This also means that you can run the rake task from your development machine
and completely migrate the assets before your deploy, minimizing the chances
that you'll have a timed-out deployment.

The main drawback of this method is the same as its benefit - you are
essentially duplicating all of your assets. These days storage and bandwidth
are relatively cheap, but in some instances where you have a huge volume of
files, or very large file sizes, this might get a little less feasible.

In my experience I was able to move tens of thousands of images in a matter of
a couple of hours, just by running the migration overnight on my MacBook Pro.

Once you've confirmed that the migration and deploy have gone successfully you
can safely delete the old assets from your remote host.

## Update your tests

Instead of the `have_attached_file` matcher, you'll need to write your own.
Here's one that is similar in spirit to the Paperclip-supplied matcher:

```ruby
RSpec::Matchers.define :have_attached_file do |name|
  matches do |record|
    file = record.send(name)
    file.respond_to?(:variant) && file.respond_to?(:attach)
  end
end
```

## Update your views

In Paperclip it looks like this:

```ruby
image_tag @user.avatar.url(:medium)
```

In ActiveStorage it looks like this:

```ruby
image_tag @user.avatar.variant(resize: "250x250")
```

## Update your controllers

This should _require_ no update. However, if you glance back at the database
schema above, you may notice a join.

For example, if your controller has

```ruby
def index
  @users = User.all.order(:name)
end
```

And your view has

```
<ul>
  <% @users.each do |user| %>
    <li><%= image_tag user.avatar.variant(resize: "10x10"), alt: user.name %></li>
  <% end %>
</ul>
```

Then you'll end up with an n+1 as you load each attachment in the loop.

So while the controller and model will work without change, you will want to
double-check your loops and add `includes` as needed. ActiveStorage adds an
`avatar_attachment` and `avatar_blob` relationship to has-one relations, and
`avatar_attachments` and `avatar_blobs` to has-many:

```ruby
def index
  @users = User.all.order(:name).includes(:avatar_attachment)
end
```

## Update your models

Follow [the guide on attaching files to records]. For example, a `User` with an
`avatar` is represented as:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end
```

Any resizing is done in the view as a variant.

[the guide on attaching files to records]: http://edgeguides.rubyonrails.org/active_storage_overview.html#attaching-files-to-records

## Remove Paperclip

Remove the Gem from your `Gemfile` and run `bundle`. Run your tests because
you're done!
