module Growl
  # Default error for anything that goes wrong with a Growl::Application.
  class GrowlApplicationError < StandardError
  end
  
  # Default error for anything that goes wrong with a Growl::Notification.
  class GrowlMessageError < StandardError
  end
  
  # Error raised when Growl isn't installed.
  class GrowlIsNotInstalled < StandardError
  end
  
  # Error raised when Growl is not currently running. In the process of creating a new application
  # using Growl.application, the application is set as a GrowlApplicationBridgeDelegate, which
  # nominally starts Growl; however, RubyCocoa has the nasty tendency to seg-fault unless Growl
  # is already running anyway. In short, your program should crash horribly before you'll ever see
  # this error.
  class GrowlIsNotRunning < StandardError
  end
end