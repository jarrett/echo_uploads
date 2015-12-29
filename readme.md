Echo Uploads is uploaded files for Rails, done right. It gracefully handles invalid form
submissions so users don't have to resubmit the file. It supports transforming the file
before saving, e.g. scaling an image. It's compatible with any storage mechanism,
including the local filesystem and the cloud. 

# Usage

## Installation

In your application's Gemfile:

    gem 'echo_uploads'

## Metadata Model

Echo Uploads requires a special-pupose ActiveRecord model for storing metadata. The model
class, `EchoUploads::File`, is provided by the gem. Create the the table as
follows:
    
    create_table :echo_uploads_files do |t|
      t.integer :owner_id
      t.string :owner_type
      t.string :owner_attr
      t.string :storage_type
      t.string :key
      t.string :original_basename
      t.string :original_extension
      t.string :mime_type
      t.integer :size
      t.boolean :temporary
      t.datetime :expires_at
      t.timestamps
    end
    add_index :echo_uploads_files, :owner_id
    add_index :echo_uploads_files, :key
    add_index :echo_uploads_files, :temporary

## Your Model

With that infrastructure in place, you can start adding uploaded file attributes to your
models. For example, let's say you have a model call `Widget`, and you want to give each
widget a `thumbnail` attribute. You'd do the following:

    class Widget < ActiveRecord::Base
      include EchoUploads::Model
      
      echo_upload :thumbnail
    end
    
    create_table :widgets do |t|
      # Just define your migration as normal. You don't need to include any special
      # fields for EchoUploads.
    end

## Forms

In the views, you define a file field like normal. The only trick is: You also have to
include a hidden field for Echo Uploads' metadata. Its purpose is to "remember" info about
the uploaded files if validation fails, or if the form is multi-step. The field is
encoded as base-64 JSON.

Regardless of how many files you upload to the model, you only need to
include the `:echo_uploads_data` field once.

    <%= form_for @widget do |f| %>
      <!-- If we're redisplaying this form due to validation errors, and none of the
      errors were on the uploaded file, we don't want to redisplay the file field. -->
      <% unless @widget.has_tmp_file? :thumbnail %>
        <div>
          <%= f.label :thumbnail, 'Thumbnail:' %>
          <%= f.file_field :thumbnail %>
        </div>
      <% end %>
      
      <!-- Any other fields for this model -->
      
      <div>
        <%= f.submit 'Save' %>
        
        <!-- Include this only once, even if you have multiple file attributes on the
        same model -->
        <%= f.hidden_field :echo_uploads_data %>
      </div>
    <% end %>

## Controller

The controller is pretty standard. Just remember to permit the correct form fields:

    class WidgetsController < ApplicationController
      def create
        @widget = Widget.new widget_params
        if @widget.save
          redirect_to widgets_url
        else
          render action: :new
        end
      end
      
      def new
        @widget = Widget.new
      end
      
      private
      
      def widget_params
        params.require(:widget).permit(:thumbnail, :echo_uploads_data)
      end
    end

## Downloading the Uploaded File

To make uploaded files available for download (whether to be saved to the user's disk,
displayed as images on the page, or anything else), you can add a method to your
controller like this:

    def download
      widget = Widget.find params[:id]
      send_file(widget.thumbnail_path,
        type: widget.thumbnail_mime,
        disposition: 'inline',
        # You probably wouldn't really send the original filename when displaying an
        # image. This is more useful for files the user saves to disk. It's included
        # here just to show you how.
        filename: widget.thumbnail_original_filename
      )
    end

As you can see, Echo Uploads has automatically added the methods `#thumbnail_mime` and
`#thumbnail_original_filename` (amongst others).

If you want to use `send_data` instead of `send_file`, you can do something like this:

    send_data widget.read_thumbnail

## Validation

EchoUploads comes with some basic validations:

    class Widget < ActiveRecord::Base
      include EchoUploads::Model
      
      echo_upload :thumbnail
      
      validates :thumbnail, upload: {presence: true, max_size: 1.megabyte, extension: ['.jpg', '.png']}
    end

The `presence` validator doesn't require a new file to be uploaded on every request cycle.
(That's rarely what you want.) If no file has been submitted this request cycle, but a
file was previously saved, the `presence` validator passes. Internally, it uses the
`has_x?` method--which, in the example above, would be `has_thumbnail?`.

You can perform custom validations on the uploaded file. Because Echo Uploads defines
normal attribute methods for uploaded files, you can validate those attributes like any
other.

    class Widget < ActiveRecord::Base
      include EchoUploads::Model
      
      echo_upload :thumbnail
      
      validates :thumbnail, upload: {presence: true}
      validate :thumbnail_formatted_correctly
      
      def thumbnail_formatted_correctly
        begin
          SomeImageLibrary.parse thumbnail.read
        rescue
          errors.add :thumbnail, 'is not a valid image'
        end
      end
    end

## Transforming the Uploaded File, e.g. Resizing an Image

Sometimes you need to transform the uploaded file before it's saved, e.g. cropping and
resizing an image. To do that, pass a `:map` option to `echo_upload`:

    class Widget < ActiveRecord::Base
      include EchoUploads::Model
      
      echo_upload :thumbnail, map: :resize_thumbnail
      
      def resize_thumbnail(input_image, mapper)
        # We use ImageScience in this example, but you could also use ImageMagick or
        # any other image resizing library. You could also shell out and call a
        # command-line library.
        input_image.cropped_thumbnail(200) do |out_image|
          # The extension argument for Mapper#write gets appended to the out_file_path.
          mapper.write('.png') do |out_file_path|
            out_image.save out_file_path
          end
        end
      end
    end

The `:map` option can accept either a proc or the name of an instance method as a symbol.
The proc or method takes two arguments: the original file, which is an instance of `File`;
and an instance of `EchoUploads::Mapper`. You call `#write` on the mapper for every output
file you want to write. `#write` yields the path to which the output file must be written.

Mapping occurs in an `after_save` callback. Thus, if validation fails, only the original
uploaded file is persisted.

You might need to access the transformed file, e.g. in a validation method. If so,
it's available under an attribute called `"mapped_#{attr}"`, where `attr` is the name
of the attribute. For example, if you call:

    echo_upload :thumbnail, map: :resize_thumbnail

...then the transformed file will be available under an attribute called
`#mapped_thumbnail`.

## Multiple Mapped Files

Suppose you want to create more than one version of the uploaded file. For example,
maybe you want to make thumbnails of different sizes. For that, you use the `:multiple`
options:

    class Widget < ActiveRecord::Base
      include EchoUploads::Model
      
      echo_upload :thumbnail, map: :resize_thumbnail, multiple: true
      
      def resize_thumbnail(input_image, mapper)
        [100, 200].each do |size|
          input_image.cropped_thumbnail(size) do |out_image|
            # You can call mapper.write as many times as you want. Each time you call it,
            # it will yield a different tempfile path.
            mapper.write do |out_file_path|
              out_image.save(out_file_path + '.png')
              FileUtils.mv(out_file_path + '.png', out_file_path)
            end
          end
        end
      end
    end

With the `:multiple` option, you'll be able to address each mapped file individually. For
example:

    widget.thumbnails[0].path
    widget.thumbnails[0].key

## Custom File Stores

Echo Uploads allows you to store your files in any location and in any manner you want.
Off-the-shelf, it comes with a local filesystem store (`EchoUploads::FilesystemStore`),
which is the default. You can also define you own:

    class MyFileStore < EchoUploads::AbstractStore
      # Persists the file under the given key. Accepts a File. Typically should check to
      # see if a file with the same key already exists, and if so, do nothing. metadata
      # is an EchoUploads::File.
      def write(key, file, metadata)
        # ...
      end
      
      # Returns the stored data as a String.
      def read(key)
        # ...
      end
      
      # Deletes the file with the given key.
      def delete(key)
        # ...
      end
      
      # Checks whether the given key exists.
      def exists?(key)
        # ...
      end
      
      # Optional. Opens the given key and yields an IO object. Not applicable to all
      # storage mechanisms.
      def open(key)
        # ...
      end
      
      # Optional. Returns a filesystem path to the stored file. Useful for X-Sendfile and
      # similar. Not applicable to all storage mechanisms.
      def path(key)
        # ...
      end
    end
    
    class Widget < ActiveRecord::Base
      include EchoUploads::Model
      
      echo_upload :thumbnail, storage: 'MyFileStore'
    end

Or, instead of passing the `:storage` option to the `echo_uploads` method, you can
configure it application-wide:

    # In config/application.rb, config/production.rb, etc.
    config.echo_uploads.storage = 'MyFileStore'

## Filesystem Store

The default, built-in file store uses the server's local filesystem. By default, it places
files in:

    "#{Rails.root}/uploads/echo_uploads/ENVIRONMENT"

...where `ENVIRONMENT` is one of `production`, `development`, or `test`.

If you're deploying with Capistrano or anything similar, be careful that you don't
re-create the upload folder on each deployment. There are two ways to avoid that.

### Option 1: Symlink

The first option is to create a folder in a permanent location, e.g. Capistrano's `shared`
folder, and symlink to that on each deployment.

In **Capistrano 3**, set a symlinked directory in `config/deploy/production.rb`:

    set :linked_dirs, fetch(:linked_dirs, []).push(:echo_uploads)

In **Capistrano 2**, edit `config/deploy.rb`:
    
    namespace :deploy do
      task :symlink_echo_uploads do    
        run "rm -rf #{deploy_to}/current/echo_uploads/production"
        run "ln -s #{deploy_to}/shared/echo_uploads #{deploy_to}/current/echo_uploads/production"
      end
    end
    
    after 'deploy:create_symlink', 'deploy:symlink_echo_uploads'

### Option 2: Override Echo Uploads Default Folder

The second option is to create a folder in a permanent location and configure EchoUploads
to use it:

    # In production.rb:
    config.echo_uploads.folder = 'path/to/permanent/folder'

## S3 Store

Echo Uploads also comes with a built-in adapter for Amazon S3. To use it:

    # In config/application.rb, config/production.rb, etc.
    config.echo_uploads.storage = 'EchoUploads::S3Store'

If you're going to use the built-in S3 adapter, you must configure the bucket in which
Echo Uploads will store files:

    # In config/application.rb, config/production.rb, etc.
    config.echo_uploads.s3.bucket = 'my-bucket'

By default, it places files in the following path within your bucket:

    "echo_uploads/ENVIRONMENT"

...where `ENVIRONMENT` is one of `production`, `development`, or `test`. Be sure to create
the necessary folder(s) on S3. You can override the path within the bucket like this:
    
    # In config/application.rb, config/production.rb, etc.
    config.echo_uploads.s3.folder = 'custom/per-environment/folder'

By default, Echo Uploads assumes you've configured the aws-sdk gem at the application
level, like this:

    # In config/application.rb, config/production.rb, etc.
    AWS.config access_key_id: '...', secret_access_key: '...', region: 'us-west-2'

However, if you need to configure AWS application-wide and yet use a *different* config
just for Echo Uploads, you can do this:

    # In config/application.rb, config/production.rb, etc.
    configuration.echo_uploads.aws = {
      access_key_id: '...', secret_access_key: '...', region: 'us-west-2'
    }

## Model Methods Reference

Echo Uploads adds some methods to your model. Let's assume you called:

    echo_upload :thumbnail

Then, your model would have the following methods:

  * `thumbnail_path`: Returns the path on disk to the file. Not applicable for some
    file stores, such as Amazon S3.
  * `read_thumbnail`: Returns the binary data.
  * `thumbnail_size`: Returns the file size in bytes.
  * `thumbnail_original_filename`: Returns the name of the file as it existed on the
    user's disk.
  * `thumbnail_mime`: Returns the MIME type of the file. Aliased as `thumbnail_mime_type`.
  * `thumbnail_key`: Returns the file's unique key (usually a SHA-512 hash).
  * `has_prm_thumbnail?`: Whether a permanent file exists.
  * `has_tmp_thumbnail?`: Whether a temporary file exists.

## Eager-loading with `#includes`

Each uploaded file has exactly one corresponding record in the metadata table. (See
"Metadata Table" below for more info.) You may need to eager-load from that table. For
example, suppose you have a `User` model with an `avatar` upload:

    # app/models/user.rb
    class User < ActiveRecord::Base
      echo_upload :avatar
    end
    
    # app/controllers/users_controller.rb
    class UsersController < ApplicationController
      def index
        # Uh-oh. Without eager loading, this queries echo_uploads_files once per user.
        @users = User.all
      end
    end

The above has a problem. Without eager loading, the call to `User.all` queries the
`echo_uploads_files` table once per user. (To understand why, see
"[Eager Loading](http://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations)"
in the Rails guide.) This is known as the N + 1 queries problem. We can solve this with
eager loading:

    @users = User.includes(:avatar_metadata)

This works because Echo Uploads defines an association called `avatar_metadata`. Each
call to `echo_upload` defines a new association, where the name is
`your_attribute_name_metadata`. For example, `echo_upload :photo` would define the
association `photo_metadata`, `echo_upload :zip_file` would define `zip_file_metadata`,
etc.

## Nested attributes

Suppose you call `accepts_nested_attributes_for`, and the child model has any Echo Uploads
attributes. For example:
    
    # app/models/user.rb
    class User < ActiveRecord::Base
      has_many :avatars
      accepts_nested_attributes_for :avatars
      validates :email, presence: true
    end
    
    # app/models/avatar.rb
    class Avatar < ActiveRecord::Base
      include EchoUploads::Model
      
      belongs_to :user
      echo_upload :image
    end
    
    # app/controllers/users_controller.rb
    class UsersController < ApplicationController
      def create  
        @user = User.new user_params
        if @user.save
          redirect_to '/'
        else
          render action: :new
        end
      end
      
      # ...
      
      private
      
      def user_params
        params.require(:user).permit(:email, avatars_params: [:image, :echo_uploads_data])
      end
    end

This mostly works. But if validation fails during the `#create` action, the avatars'
uploaded images won't be persisted. (That's bad. We'd like to re-display the form with the
uploaded images pre-populated, saving the user from having to upload them again.) The
uploaded avatar images don't persist because that would normally occur during
`Avatar#save`. But when the `User` validation fails, ActiveRecord doesn't call `#save` on
the nested records.

To work around this limitation of ActiveRecord, we need to add a callback to the parent
model:

    # app/models/user.rb
    class User < ActiveRecord::Base
      # Provides the after_failed_save callback. Implicitly includes EchoUploads::Model.
      include EchoUploads::Callbacks
      
      has_many :avatars
      accepts_nested_attributes_for :avatars
      validates :email, presence: true
      
      after_failed_save do
        # Iterate over the nested records, writing a temporary file where possible.
        avatars.each(&:maybe_write_tmp_image)
      end
    end

# How it Works

## The Metadata Table

As mentioned, Echo Uploads stores metadata for all the files it manages in a single table.
Even if you have dozens of models with all different kinds of associated files, their
metadata would all be in that same table.

Echo Uploads manages the lifecycle of objects in that table. You should never have to
create, update, or delete them.

Each record in the table represents one file-owner relationship, but because of
de-duplication, multiple records may point to the same underlying file. (See below under
"Keys" for details about de-duplication.)

When you call `echo_upload` in your model, one of the many things it does is establish
a `has_one` association between your model and the metadata model.

## Keys

Regardless of the chosen store, each file is identified by a "key," which is a unique
string identifier. By default, the key is the SHA-512 hash of the file data.

This means files are de-duplicated. In other words, if identical files are uploaded, only
one copy will be stored. However—and this is important—each copy of the file will have its
own record in the metadata table.

You can override the key algorithm like this:

    echo_upload :thumbnail, key: ->(file) { some_hash_function file.read }

## Deletion of Unused Files

Files are automatically deleted when they're no longer used. Each time a metadata record
is destroyed, it checks to see if there are any other metadata records with the same
key. If there aren't, then the underlying file is deleted.

## Invalid Form Submissions, Multi-step Forms

Suppose a user submits a form with an uploaded file, and the model's validation fails for
whatever reason. Or, suppose you have a multi-step form in which the model does not save
until the very last step. In either case, you probably want the uploaded file to be stored
temporarily. The form should "remember" what the user uploaded a moment ago.

Echo Upload supports that workflow out-of-the-box. Uploaded files are persisted
immediately, even if the model that owns them isn't saved. Initially, the `temporary`
column in the metadata table is set to `true`. When the owner object is finally saved, the
`temporary` column is set to `false`.

When a form is redisplayed, or when a later part of a multi-step form is displayed, the
uploaded file's key is propagated via the call to `f.hidden_field :echo_uploads_data`.
Thanks to this data, the model "remembers" the previously uploaded file upon the next
form submission.

Sometimes, users abandon their form submissions, leaving temporary files that will never
be finalized. These get pruned after an expiration period.

Looking deeper under the hood, here's when each of the above steps happens:

* The initial saving occurs when the model's attribute writer method is called. For
  example, on a `Widget` class that calls `echo_upload :thumbnail`, persistence occurs
  when `thumbnail=` is called. `temporary` is set to true at this moment. There is one
  important exception, though: The file is *not* persisted if there were validation errors
  on the file itself.

* `temporary` is set to false in an `after_save` callback. (That's `after_save` on the
  `Widget` model.)

* Pruning of expired temporary files occurs every time a new file is written. If you want
  to disable that behavior (because you want more control over when pruning occurs), call
  `config.echo_uploads.prune_tmp_files_on_upload = false` in your application config.
  To manually prune, call `EchoUploads.prune!`.

## Does the default key algorithm (SHA-512) provide a way to attack Echo Uploads?

As of June 2014, no.

Hypothetically, if someone discovers a way to compute a matching input from a SHA-512
hash, an attack would be possible. Knowing the contents of an uploaded file, or the
SHA-512 hash thereof, an attacker could craft a harmful file with the same SHA-512 hash.
If the attacker uploaded that file, it would overwrite the original.

Currently (as of June 2014), there is no publicly known way to compute a matching input
from a SHA-512 hash. So the attack is not currently possible. If that changes, Echo
Uploads will have to stop using SHA-512, and existing filestores will have to be migrated.