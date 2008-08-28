module Growl
  
  class << self
    @@framework_loaded = false
    
    mattr_reader :framework_loaded

    # Returns true if Growl is installed.
    def is_installed?
      application_bridge.isGrowlInstalled == 1
    end

    # Returns true if Growl is currently running. Using Growler while Growl isn't running
    # usually causes a segementation fault.
    def is_running?
      application_bridge.isGrowlRunning == 1
    end

    # Returns the GrowlApplicationBridge object, which has various methods for posting
    # notifications and checking to see if Growl is installed and running.
    def application_bridge
      OSX::GrowlApplicationBridge
    end

    private

    # Loads the Growl.framework located in the ext directory. Loading this framework brings all
    # the applicable Objective C classes across the RubyCocoa bridge into Ruby, giving us access
    # to cool things like the GrowlApplicationBridge, which makes posting to Growl possible.
    def load_framework!
      framework = OSX::NSBundle.bundleWithPath(BUNDLE_PATH)
      if framework
        @@framework_loaded = framework.load
      else
        # raise GrowlApplicationError, "The Growl Framework was not loaded. It could be missing."
        @@framework_loaded = false
      end
    end
  end
  
end