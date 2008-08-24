module Growl
  
  class << self
    @@framework_loaded = false

    def framework_loaded?
      @@framework_loaded
    end

    # Returns true if Growl is installed.
    def is_installed?
      application_bridge.isGrowlInstalled == 1
    end

    # Returns true if Growl is currently running. Using Growler while Growl isn't running
    # usually causes a segementation fault.
    def is_running?
      application_bridge.isGrowlRunning == 1
    end

    def application_bridge
      OSX::GrowlApplicationBridge
    end

    private

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