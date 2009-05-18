require 'rubygems'
require 'couch_foo'

class User < CouchFoo::Base
  property :email, String
  property :active, String
  property :created_at, DateTime

  default_sort :created_at
end

CouchFoo::Base.set_database(:host => 'http://localhost:5984', :database => 'newzbin')
CouchFoo::Base.logger = Logger.new(File.join(File.dirname(__FILE__), 'couchfoo.log'))

