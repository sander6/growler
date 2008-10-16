require 'rubygems'
require 'md5'
require 'socket'

module Growl; end

$LOAD_PATH.unshift(File.dirname(__FILE__))

# Certain libraries depend on RubyCocoa. We won't load those libraries if it's not available.
# We'll also suppress functionality in other libraries that depend on those.
# It seems silly to try to get any usability at all out of this gem considering that it's
# for the Mac-only Growl framework, but we can still try to eek out some network functionality
# on non-Mac platforms.

require 'growler/helpers/object_extensions'
require 'growler/helpers/module_extensions'
require 'growler/helpers/hash_extensions'
require 'growler/dynamic_string'
require 'growler/errors'
require 'growler/defines' # Here's where Growl::COCOA is defined.
require 'growler/framework' if Growl::COCOA
require 'growler/extractors/image_extractor' if Growl::COCOA
require 'growler/extractors/priority_extractor'
require 'growler/growl'
require 'growler/networky'
if Growl::COCOA
  require 'growler/application'
  require 'growler/notification'
else
  require 'growler/non_osx_application'
  require 'growler/non_osx_notification'
  Growl::Application = Growl::NonOSXApplication
  Growl::Notification = Growl::NonOSXNotification
end
# require Growl::COCOA ? 'growler/application' : 'growler/non_osx_application'
# require Growl::COCOA ? 'growler/notification' : 'growler/non_osx_notification'
require 'growler/version'