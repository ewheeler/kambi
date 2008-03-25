#!/usr/bin/env ruby
# This is a RESTful extension of the Camping-based Blokk project:
# http://murfy.de/read/blokk
#
# The original Camping-based Blog can be found here: 
# http://code.whytheluckystiff.net/camping/browser/trunk/examples/blog.rb
#
# Borrows from RESTstop's adaptation: http://reststop.rubyforge.org/classes/Camping.html
#
# Tag cloud courtesy of: http://whomwah.com/2006/07/06/another-tag-cloud-script-for-ruby-on-rails/

# TODO: photo/file uploads?


require 'rubygems'

gem 'camping', '~> 1.5'
gem 'reststop', '~> 0.2'

require "camping"
require "htmlentities"

begin
  # try to use local copy of library
  require '../lib/reststop'
rescue LoadError
  # ... otherwise default to rubygem
  require 'reststop'
end


require 'camping/db'
require 'camping/session'
   
gem 'turing'
require 'turing'

gem 'redcloth'
require 'redcloth'
    
Camping.goes :Kambi

module Kambi   
    require 'kambi/helpers'
    require 'kambi/models'
    require 'kambi/views'
    require 'kambi/controllers'
    include Camping::Session
end


def Kambi.create
    # NOTE: when using mysql, you have to make the sessions table manually:
    # CREATE TABLE `sessions` (`id` int(11) DEFAULT NULL auto_increment PRIMARY KEY, `hashid` varchar(32) DEFAULT NULL, `created_at` datetime DEFAULT NULL, `ivars` text DEFAULT NULL)
    #
    # then make a .campingrc file in users home folder:
    # host : 127.0.0.1
    # port : 3301
    # server : mongrel
    # database :
    #   :adapter: mysql
    #   :database: kambi
    #   :hostname: localhost
    #   :username: root
    #   :password: root
    # log:
    #   kambi.log
    
    Camping::Models::Session.create_schema
    Kambi::Models.create_schema
end

# TODO: what is this class? removing
# it seem to have no effect at all
class Mab
  def initialize(assigns = {}, helpers = nil, &block)
    super(assigns.merge({:indent => 2}), helpers, &block)
  end
  def xhtml11(&block)
    self.tagset = Markaby::XHTMLStrict
    declare! :DOCTYPE, :html, :PUBLIC, '-//W3C//DTD XHTML 1.1//EN', 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'
    tag!(:html, :xmlns => 'http://www.w3.org/1999/xhtml', 'xml:lang' => 'en', &block)
    self
  end
end



Markaby::Builder.set(:indent, 2)

# 
# if __FILE__ == $0
#   require 'mongrel/camping'
# 
#   Kambi::Models::Base.establish_connection :adapter => 'mysql', 
#     :database => 'kambi_dev', 
#     :username => 'root', 
#     :password => 'root'
#   Kambi::Models::Base.logger = Logger.new('kambi.log')
#   #Kambi::Models::Base.threaded_connections = false
#   Kambi.create # only if you have a .create method 
#                  # for loading the schema
# 
#   server = Mongrel::Camping::start("0.0.0.0",80,"/", Kambi)
#   puts "Kambi is running at http://localhost:80/"
#   server.run.join
# end
