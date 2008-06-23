require 'rubygems'

module Growl; end

$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'growler/growl'
require 'growler/application'
require 'growler/notification'
require 'growler/application_bridge'
require 'growler/application_delegate'