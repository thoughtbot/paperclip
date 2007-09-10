require 'open-uri'
require File.join(File.dirname(__FILE__), "lib", "paperclip")
ActiveRecord::Base.extend( Thoughtbot::Paperclip::ClassMethods )
File.send :include, Thoughtbot::Paperclip::Upfile
URI.send :include, Thoughtbot::Paperclip::Upfile