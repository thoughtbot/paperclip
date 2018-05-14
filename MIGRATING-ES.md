# Migrando de Paperclip a ActiveStorage

Paperclip y ActiveStorage resuelven problemas similares con soluciones
similares, por lo que pasar de uno a otro es simple.

El proceso de ir desde Paperclip hacia ActiveStorage es como sigue:

1. Implementa las migraciones a la base de datos de ActiveStorage.
2. Configura el almacenamiento.
3. Copia la base de datos.
4. Copia los archivos.
5. Actualiza tus pruebas.
6. Actualiza tus vistas.
7. Actualiza tus controladores.
8. Actualiza tus modelos.

## Implementa las migraciones a la base de datos de ActiveStorage

Sigue [las instrucciones para instalar ActiveStorage]. Muy probablemente vas a
querer agregar la gema `mini_magick` a tu Gemfile.


```sh
rails active_storage:install
```

[las instrucciones para instalar ActiveStorage]: https://github.com/rails/rails/blob/master/activestorage/README.md#installation

## Configura el almacenamiento

De nuevo, sigue [las instrucciones para configurar ActiveStorage].

[las instrucciones para configurar ActiveStorage]: http://edgeguides.rubyonrails.org/active_storage_overview.html#setup

## Copia la base de datos.

Las tablas `active_storage_blobs` y`active_storage_attachments` son en donde
ActiveStorage espera encontrar los metadatos del archivo. Paperclip almacena los
metadatos del archivo directamente en en la tabla del objeto asociado.

Vas a necesitar escribir una migración para esta conversión. Proveer un script
simple, es complicado porque están involucrados tus modelos. ¡Pero lo
intentaremos!

Así sería para un `User` con un `avatar` en Paperclip:

```ruby
class User < ApplicationRecord
  has_attached_file :avatar
end
```

Tus migraciones de Paperclip producirán una tabla como la siguiente:

```ruby
create_table "users", force: :cascade do |t|
  t.string "avatar_file_name"
  t.string "avatar_content_type"
  t.integer "avatar_file_size"
  t.datetime "avatar_updated_at"
end
```

Y tu la convertirás en estas tablas:

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

Así que asumiendo que quieres dejar los archivos en el mismo lugar, _esta es tu
migración_. De otra forma, ve la siguiente sección primero y modifica la
migración como corresponda.

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
        key, filename, content_type, metadata, byte_size,
        checksum, created_at
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
    # Alternativamente:
    # instance.send("#{attachment}_file_name")
  end

  def checksum(attachment)
    # archivos locales almacenados en disco:
    url = attachment.path
    Digest::MD5.base64digest(File.read(url))

    # archivos remotos almacenados en la computadora de alguién más:
    # url = attachment.url
    # Digest::MD5.base64digest(Net::HTTP.get(URI(url)))
  end
end
```

## Copia los archivos

La migración de arriba deja los archivos como estaban. Sin embargo,
los servicios de Paperclip y ActiveStorage utilizan diferentes ubicaciones.

Por defecto, Paperclip se ve así:

```
public/system/users/avatars/000/000/004/original/the-mystery-of-life.png
```

Y ActiveStorage se ve así:

```
storage/xM/RX/xMRXuT6nqpoiConJFQJFt6c9
```

Ese `xMRXuT6nqpoiConJFQJFt6c9` es el valor de `active_storage_blobs.key`. En la
migración de arriba usamos simplemente el nombre del archivo, pero tal vez
quieras usar un UUID.

Migrando los archivos en un hospedaje externo (S3, Azure Storage, GCS, etc.)
está fuera del alcance de este documento inicial. Así es como se vería para un
almacenamiento local:

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

## Actualiza tus pruebas

En lugar de utilizar `have_attached_file`, será necesario que escribas tu propio
matcher. Aquí hay un matcher similar _en espíritu_ al que Paperclip provee:


```ruby
RSpec::Matchers.define :have_attached_file do |name|
  matches do |record|
    file = record.send(name)
    file.respond_to?(:variant) && file.respond_to?(:attach)
  end
end
```

## Actualiza tus vistas

En Paperclip se ven así:

```ruby
image_tag @user.avatar.url(:medium)
```

En ActiveStorage se ven así:

```ruby
image_tag @user.avatar.variant(resize: "250x250")
```

## Actualiza tus controladores

Esto no debería _requerir_ ningúna actualización. Sin embargo, si te fijas en
el schema de tu base de datos, notaras un join.

Por ejemplo si tu controlador tiene:

```ruby
def index
  @users = User.all.order(:name)
end
```

Y tu vista tiene:

```
<ul>
  <% @users.each do |user| %>
    <li><%= image_tag user.avatar.variant(resize: "10x10"), alt: user.name %></li>
  <% end %>
</ul>
```

Vas a terminar con un n+1, ya que descargas cada archivo adjunto dentro del
bucle.

Así que mientras que el controlador y el modelo funcionarán sin ningún cambio,
tal vez quieras revisar dos veces tus bucles y agregar `includes` en dónde haga
falta.

ActiveStorage agrega `avatar_attachment` y `avatar_blob` a las relaciones del
tipo `has-one`, así como `avatar_attachments` y `avatar_blobs` a las relaciones
de tipo `has-many`:

```ruby
def index
  @users = User.all.order(:name).includes(:avatar_attachment)
end
```

## Actualiza tus modelos

Sigue [la guía sobre cómo adjuntar archivos a los registros]. Por ejemplo, un
`User` con un `avatar` se representa como:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end
```

Cualquier cambio de tamaño se hace en la vista como un `variant`.

[la guía sobre cómo adjuntar archivos a los registros]: http://edgeguides.rubyonrails.org/active_storage_overview.html#attaching-files-to-records

## Quita Paperclip

Quita la gema de tu `Gemfile` y corre `bundle`. Corre tus pruebas porque ya
terminaste!
