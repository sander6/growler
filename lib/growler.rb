require 'rubygems'

module Growl; end

$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'growler/growl'
require 'growler/application'
require 'growler/notification'
require 'growler/transmogrifier'