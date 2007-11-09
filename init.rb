require File.join(File.dirname(__FILE__), "lib", "paperclip")
ActiveRecord::Base.extend( Paperclip::ClassMethods )
File.send :include, Paperclip::Upfile