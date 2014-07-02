# Usage

## Metadata Model

Echo Uploads requires a special-pupose ActiveRecord model for storing metadata. The model
class, `EchoUploads::File`, is provided by the gem. Create the the table as
follows:
    
    create_table :echo_uploads_files do |t|
      t.integer :owner_id
      t.string :owner_type
      t.string :storage_type
      t.string :key
      t.string :original_basename
      t.string :original_extension
      t.string :mime_type
      t.boolean :temporary
      t.datetime :expires_at
      t.timestamps
    end
    add_index :echo_uploads_files, :owner_id
    add_index :echo_uploads_files, :key
    add_index :echo_uploads_files, :temporary

## Choosing a File Store

Echo Uploads allows you to store your files in any location and in any manner you want.
Off-the-shelf, it comes with a local filesystem store (`EchoUploads::FilesystemStore`),
but you can define you own:

    class Widget < ActiveRecord::Base
      include EchoUploads
      
      echo_upload :thumbnail, storage: MyFileStore
    end
    
    class MyFileStore < EchoUploads::AbstractStore
      # Persists the file under the given key. Accepts an ActionDispatch::UploadedFile.
      # Typically should check to see if a file with the same key already exists, and if
      # so, do nothing.
      def write(key, file)
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

## Validation

You can perform custom validations on the uploaded file. Because Echo Uploads defines
normal attribute methods for uploaded files, you can validate those attributes like any
other.

    class Widget < ActiveRecord::Base
      include EchoUploads::Model
      
      echo_upload :thumbnail
      
      validates :thumbnail, presence: true
      validate :thumbnail_formatted_correctly
      
      def thumbnail_formatted_correctly
        begin
          SomeImageLibrary.parse thumbnail.read
        rescue
          errors.add :thumbnail, 'is not a valid image'
        end
      end
    end

# How it Works

## The Metadata Table

As mentioned under "Usage," Echo Uploads stores metadata for all the files it manages in a
single table. Even if you have dozens of models with all different kinds of associated
files, their metadata would all be in that same table.

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
hash, an attack would be possible. Knowing contents of an uploaded file, or the SHA-512
hash thereof, an attacker could craft a harmful file with the same SHA-512 hash. If the
attacker uploaded that file, it would overwrite the original.

Currently (as of June 2014), there is no publicly known way to compute a matching input
from a SHA-512 hash. So the attack is not currently possible. If that changes, Echo
Uploads will have to stop using SHA-512, and existing filestores will have to be migrated.

## Filesystem Store

The default, built-in file store uses the server's local filesystem. By default, it places
files in `"#{Rails.root}/uploads/echo_uploads"`.

If you're deploying with Capistrano or anything similar, be careful that you don't
re-create the upload folder on each deployment. There are two ways to avoid that.

The first option is to create a folder in a permanent location, e.g. Capistrano's `shared`
folder, and symlink to that on each deployment.

The second option is to create a folder in a permanent location and configure EchoUploads
to use it:

    # In production.rb, specify the default folder. Can be overridden per attribute.
    config.echo_uploads.default_folder = '/some/folder'
    
    # In a model, specify the folder per attribute. Takes precence over the above.
    class Widget < ActiveRecord::Base
      include EchoUploads::Model
      
      echo_upload :thumbnail, folder: '/some/folder'
    end