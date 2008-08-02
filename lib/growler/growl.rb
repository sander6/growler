require 'osx/cocoa'

# For simple scripts it's easier to just send one-off notifications without going through the
# rigmarole of setting configuration and registering the application. For the times when that
# would be overkill, the Growl module itself can be used to send simple notifications.
#
# Unlike Growl::Notification, which taps into the Cocoa bindings for Growl, the Growl
# module simply wraps the growlnotify command-line utility. You might find that this is
# more convenient and powerful in some cases, since it's simple and has a much easier time
# with custom notification icons. Obviously, you must have growlnotify installed.
#
# The advantage of Growler's CLI wrapper in comparison to previous attempts, beyond the
# automatic Leopard fix and data-massaging (see below for details about both), is that
# message attributes are saved as instance attributes on the Growl module itself,
# (yes, this is valid Ruby; Modules are just as much objects as anything else) meaning
# that you can easily send multiple, similar messages without having to repeat yourself
# over and over again.
#
# To use, set your messages attributes on the Growl module directly, then call Growl.post
# to post the message.
#
# The attributes are as follows:
# * :message - the body of the notification.
# * :title - the title of the notification.
# * :sticky - boolean; whether or not the notification is sticky. Default false.
# * :icon - a file type or extension to use as this notification's icon.
# * :password - password to send to a remote machine.
# * :host - host to send the notification to. Default is "localhost" to fix a bug in Leopard.
# * :name - the name of the notification. If the name you specify isn't found by Growl in the list of available notifications for the application you specify, nothing will actually get posted. The default argument is nil, which Growl interprets to mean "Command-Line Growl Notification".
# * :path - path to the growlnotify utility. Default "/usr/local/bin/growlnotify"
# * :app_name - name of the application sending the notification. Default nil, which Growl interprets as "growlnotify". Note that if you set the :app_name to something, that application will have to already be registered with Growl, else no notification will show up.
# * :app_icon - name of an application (in /Applications or ~/Applications, for example) to borrow an icon from. Growl 1.1.4 eliminated the need to specifically add ".app" to the name; Growler ensures that the app name ends in ".app" to retain compatibility.
# * :icon_path - path to a file whose icon will be used for this notification's icon.
# * :image - path to an image file which should be used from this notificaiton's icon.
# * :priority - sets the priority for this message. Pass either an integer between -2 and 2 or a priority name as a symbol (:very_low, :moderate, :normal, :high, :emergency). Default 0 (:normal).
# * :udp - boolean; use UDP instead of DO to send remote notifications; currently not implemented.
# * :port - UDP port for notifications; currently not implemented.
# * :auth - digest algorithm for UDP authentication. Either :md5, :sha256, or :none. Default :md5. Currently not implemented.
# * :crypt - boolean; whether or not to encrypt UDP notifications. Currently not implemented.
# * :wait - boolean; whether or not to wait for the notification to be clicked before continuing. Currently not implemented.
# * :progress - set a progress value for this notification. Currently not implemented.
#
# Some things to be aware of:
# 1. You can set the name of the application the Growl module posts as, but the notification won't show up unless that application has already been registered. The default application name is "growlnotify", so change those settings to alter how the Growl module's notifications appear. The same holds true for notification names.
# 2. You cannot register the Growl module as an application. However, by setting the application name of the Growl module (Growl[:name] = name) to that of an already-registered application (either one you made using Growler or one from somewhere else), the notifications sent by the module will inherit the settings for that application as defined in the Growl preference pane.
# 3. There is a bug in Leopard (still persists in Leopard 10.5.3 and Growl 1.1.4) that causes many messages sent by growlnotify to be ignored. The workaround for this is to send network notifications to localhost. The Growl module does this hack automatically; however, you must check "Listen for incoming notifications" under the "Network" tab in the Growl preference pane for these notifications to show up.
# 4. None of the attributes on the Growl module will affect anything concerning Application or Notification objects (unlike how Notifications default to inheriting certain attributes from their parent Application). Think of the module as just holding a single-shot notification.
#
# Currently, setting :udp, :auth, :crypt, :port, :progress or :wait does nothing.
# Network functionality is planned for a later release, but the value of supporting :wait
# at all is debateable. Currently, I have absolutely no clue what :progress is supposed to do.

module Growl
  # The various strings Growl uses to identify certain events. I didn't make these up.
  GROWL_IS_READY = "Lend Me Some Sugar; I Am Your Neighbor!"
  GROWL_PING = "Honey, Mind Taking Out The Trash"
  GROWL_PONG = "What Do You Want From Me, Woman"
  GROWL_NOTIFICATION_CLICKED = "GrowlClicked!"
  GROWL_NOTIFICATION_TIMED_OUT = "GrowlTimedOut!"
  GROWL_KEY_CLICKED_CONTEXT = "ClickedContext"
  
  # Location of Growl.framework.
  BUNDLE_PATH = File.join(File.dirname(__FILE__), "..", "..", "ext", "Growl.framework")
  
  ATTR_NAMES = [:message, :title, :sticky, :icon, :password, :host, :name, :path, :app_name, :app_icon, :icon_path, :image, :priority, :udp, :auth, :crypt, :wait, :port, :progress]
  ATTR_NAMES.each { |a| attr_accessor a }
  
  class << self
    include Growl::PriorityExtractor
    include Growl::Returning

    def application_bridge
      OSX::GrowlApplicationBridge
    end

    # Yields a new Growl::Application to the block you provide, then registers it when done.
    #
    # This method exists to be forward compatible with eventual functionality to set a
    # Growl:Application object as a delegate of the GrowlApplicationBridge. Setting up the
    # application this way will keep users from having to remember the byzantine registration
    # steps involved and just worry about setting their own application-specific settings.
    def application
      application = returning(Growl::Application.new) { |a| yield(a) }
      returning application do |a|
        a.set_as_delegate!
        a.register!
      end
    end

    # Pass-through name-setter. Returns self so that the pass-through methods can be chained.
    # Note that the name of this notification must be registered with Growl before it can
    # be posted.
    def name(name)
      @name = name
      self
    end

    # Pass-through app_name-setter. Returns self so that the pass-through methods can be chained.
    # Note that the name of this application must be registered with Growl before it can be posted.
    def app_name(name)
      @app_name = name
      self
    end

    # Pass-through title-setter. Returns self so that the pass-through methods can be chained. Chaining
    # the methods just looks good somehow.
    def title(title)
      @title = title
      self
    end

    # Pass-through message-setter. Returns self so that the pass-through methods can be chained.        
    def message(msg)
      @message = msg
      self
    end
    
    # Pass-through icon-setter. Takes a path to an image file and uses that as this notification's
    # icon. Returns self so that the pass-through methods can be chained.
    def image(path)
      @image = transmogrify(:image, path)
      self
    end
    
    # Pass-through icon-setter. Takes a path to a file and uses that file's icon as this
    # notification's icon. Note that even if the file at the path you specify is an image, will use
    # that file's icon (e.g. the default .jpg icon) and not the file's contents (use image_path to 
    # use the file's contents). Returns self so that the pass-through methods can be chained.
    def icon_path(path)
      @icon_path = transmogrify(:icon_path, path)
      self
    end
    
    # Pass-through icon-setter. Takes a file type extension (such as "rb" or "torrent") and uses
    # the default system icon for that file type as this notification's icon. Returns self so that
    # the pass-through methods can be chained.
    def file_type(type)
      @icon = type
      self
    end
    
    # Pass-through icon-setter. Takes the name of an application (such as "Safari" or "Quicksilver")
    # and uses that application's icon for this notification's icon. Returns self so that the pass-
    # through methods can be chained.
    def app_icon(name)
      @app_icon = transmogrify(:app_icon, name)
      self
    end
    
    # Pass-through sticky-setter. Returns self so that the pass-through methods can be chained.
    def sticky(bool)
      @sticky = bool
      self
    end

    # Pass-through priority-setter. Returns self so that the pass-through methods can be chained.
    # Accepts either a priority name as a symbol (:very_low, :moderate, :normal, :high, or
    # :emergency) or an integer bewteen -2 and 2.
    def priority(value)
      @priority = get_priority_for(value)
      self
    end
  
    # Catch-all attribute reader. Used to prettify attribute reading by exposing the module's
    # attributes as if they were a hash.
    def [](attribute)
      self.instance_variable_get :"@#{attribute}"
    end
  
    # Returns a hash of the current settings.
    def get_defaults
      attributes = {}
      ATTR_NAMES.each do |attribute|
        attributes[attribute] = self[attribute]
      end
      return attributes
    end

    # Mass attribute setter. Pass attributes as a hash; returns self. Ignores any keys that aren't
    # a usable attribute. Initializes all instance variables even if they aren't set to anything;
    # this keeps a million warnings from popping up in the console.
    def set_defaults!(attrs = {})
      ATTR_NAMES.each do |attribute|
        self[attribute] = attrs[attribute] || self[attribute]
      end
      return self
    end

    # Posts a notification based on the current module settings.
    # Pass a hash of override attributes to alter the notification being posted without changing
    # any attributes on the module.
    #
    # Calls growlnotify using %x[], so returns STDOUT from the shell. If there are no glaring
    # errors in syntax, usually returns "". However, a return value of "" is no guarantee that
    # the message actually showed up on the screen. If notifications aren't showing up, read the
    # notes about "things to be aware of" at the top and see if those fix the problem.
    #
    # Aliased as notify.
    def post(overrides = {})
      %x[#{@path} #{self.build_message_string(overrides)}]
    end
    alias :notify :post

    # Just like post with automatic :sticky => true.
    #
    # Aliased as stick.
    def pin(overrides = {})
      post(overrides.merge(:sticky => true))
    end
    alias :stick :pin 
  
    # Sends the same message to each of the hosts specified.
    # Send hosts and passwords as arrays.
    # Example Growl.broadcast(["some.host", "pass"], ["some.other.host", "word"], ...)
    def broadcast(*hosts)
      hosts.each {|*host| self.post(:host => host[0], :password => host[1])}
    end
    
    # Resets all attributes back to the defaults (mostly just nil). Used in testing.
    def reset!
      @message = ""
      @title = ""
      @sticky = false
      @icon = nil
      @password = nil
      @host = "localhost"
      @name = "Command-Line Growl Notification"
      @path = "/usr/local/bin/growlnotify"
      @app_name = "growlnotify"
      @app_icon = nil
      @icon_path = nil
      @image = nil
      @priority = 0
      @udp = nil
      @auth = nil
      @crypt = nil
      @wait = nil
      @port = nil
      @progress = nil
    end

    protected

    #
    def is_installed?
      application_bridge.isGrowlInstalled
    end
    
    #
    def is_running?
      application_bridge.isGrowlRunning
    end

    # Catch-all attribute setter, used internally. Massages data just like other
    # setters (for example, automatically appends ".app" to the name when setting
    # Growl.app_icon).
    def []=(attribute, value)
      if ATTR_NAMES.include?(attribute)
        self.instance_variable_set(:"@#{attribute}", transmogrify(attribute, value)) 
      end
    end

    # Intelligently transforms simple inputs for :app_icon, :image, and :priority
    # into what growlnotify expects.
    def transmogrify(attribute, value)
      return case attribute
      when :app_icon
        (value =~ /.*\.app/ ? value : value + ".app") if value
      when :icon_path
        File.expand_path(value) if value
      when :image
        File.expand_path(value) if value
      when :priority
        get_priority_for(value)
      else
        value
      end
    end
  
    # Builds the actual command string that is passed to growlnotify.
    def build_message_string(overrides = {})
      overrides.each { |key, value| overrides[key] = transmogrify(key, value) }
      options = self.get_defaults.merge(overrides)
      str = []
      str << "-s"                            if options[:sticky]
      str << "-w"                            if options[:wait]
      str << "-n '#{options[:app_name]}'"    if options[:app_name]
      str << "-d '#{options[:name]}'"        if options[:name]
      str << "-m '#{options[:message]}'"
      str << "-i '#{options[:icon]}'"        if options[:icon]
      str << "-I '#{options[:icon_path]}'"   if options[:icon_path]
      str << "--image '#{options[:image]}'"  if options[:image]
      str << "-a '#{options[:app_icon]}'"    if options[:app_icon]
      str << "-p #{options[:priority]}"      if options[:priority]
      str << "-H #{options[:host]}"          if options[:host]
      str << "-t '#{options[:title]}'"       if options[:title]
      str.join(" ")
    end
    
    def load_framework!
      framework = OSX::NSBundle.bundleWithPath(BUNDLE_PATH)
      if framework
        framework.load
      else
        raise GrowlApplicationError, "The Growl Framework was not loaded. It could be missing."
      end
    end
    
    def setup!
      reset!
      load_framework!
      raise GrowlIsNotInstalled unless Growl.is_installed?
      raise GrowlIsNotRunning unless Growl.is_running?
    end
  end
  
  # Initialize the defaults.
  self.setup!

  # Default error for anything that goes wrong with a Growl::Application.
  class GrowlApplicationError < StandardError
  end
  
  # Default error for anything that goes wrong with a Growl::Notification.
  class GrowlMessageError < StandardError
  end
  
  # Error raised when Growl isn't installed.
  class GrowlIsNotInstalled < StandardError
    def message
      "Growl is not installed, rendering the whole point of the Growler gem rather silly."
    end
  end
  
  # Error raised when Growl is not currently running. In the process of creating a new application
  # using Growl.application, the application is set as a GrowlApplicationBridgeDelegate, which
  # nominally starts Growl; however, RubyCocoa has the nasty tendency to seg-fault unless Growl
  # is already running anyway. In short, your program should crash horribly before you'll ever see
  # this error.
  class GrowlIsNotRunning < StandardError
    def message
      "Growl is not running. Please start Growl before using the Growler gem."
    end
  end
end