# Paperclip allows file attachments that are stored in the filesystem. All graphical
# transformations are done using the Graphics/ImageMagick command line utilities and
# are stored in-memory until the record is saved. Paperclip does not require a
# separate model for storing the attachment's information, and it only requires two
# columns per attachment.
#
# Author:: Jon Yurek
# Copyright:: Copyright (c) 2007 thoughtbot, inc.
# License:: Distrbutes under the same terms as Ruby
#
# See the +has_attached_file+ documentation for more details.

require 'paperclip/paperclip'
require 'paperclip/storage'
require 'paperclip/storage/filesystem'
require 'paperclip/storage/s3'

