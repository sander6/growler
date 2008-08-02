require 'rubygems'

module Growl; end

$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'growler/extractors/image_extractor'
require 'growler/extractors/priority_extractor'
require 'growler/helpers/returning'
require 'growler/growl'
require 'growler/application'
require 'growler/notification'
require 'growler/callback'