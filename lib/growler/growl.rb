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
# * :icon - 
# * :password - password to send to a remote machine.
# * :host - host to send the notification to. Default is "localhost" to fix a bug in Leopard.
# * :name - the name of the notification. If the name you specify isn't found by Growl in the list of available notifications for the application you specify, nothing will actually get posted. The default argument is nil, which Growl interprets to mean "Command-Line Growl Notification".
# * :path - path to the growlnotify utility. Default "/usr/local/bin/growlnotify"
# * :app_name - name of the application sending the notification. Default nil, which Growl interprets as "growlnotify". Note that if you set the :app_name to something, that application will have to already be registered with Growl, else no notification will show up.
# * :app_icon - name of an application (in /Applications or ~/Applications, for example) to borrow an icon from. Growl 1.1.4 eliminated the need to specifically add ".app" to the name; Growler ensures that the app name ends in ".app" to retain compatibility.
# * :icon_path - path to a file whose icon will be used for this notification's icon.
# * :image - a file type or extension to use as this notification's icon.
# * :priority - sets the priority for this message. Pass either an integer between -2 and 2 or a priority name as a symbol (:very_low, :moderate, :normal, :high, :emergency). Default 0 (:normal).
# * :udp - boolean; use UDP instead of DO to send remote notificaiton; currently not implemented.
# * :port - UDP port for notifications; currently not implemented.
# * :auth - digest algorithm for UDP authentication. Either :md5, :sha256, or :none. Default :md5. Currently not implemented.
# * :crypt - boolean; whether or not to encrypt UDP notifications. Currently not implemented.
# * :wait - boolean; whether or not to wait for the notification to be clicked before continuing. Currently not implemented.
# * :progress - set a progress value for this notification. Currently not implemented.
# * :callback - a string of Ruby code that will be executed (via the command line "ruby -e") when this notification is clicked. If :callback is set, automatically sets :sticky => true. Note that since this is run in the command line, it's executed in the context of a new Ruby shell; that is, the code you pass will not have anything to do with the current environment that Growl.post was called in. However, a good use of :callback would be to define a meaningful return value for the post method (instead of "", which usually gets returned).
#
# Some things to be aware of:
# 1. You can set the name of the application the Growl module posts as, but the notification won't show up unless that application has already been registered. The default application name is "growlnotify", so change those settings to alter how the Growl module's notifications appear. The same holds true for notification names.
# 2. You cannot register the Growl module as an application. However, by setting the application name of the Growl module (Growl[:name] = name) to that of an already-registered application (either one you made using Growler or one from somewhere else), the notifications send by the module will inherit the settings for that application as defined in the Growl preference pane.
# 3. There is a bug in Leopard (still persists in Leopard 10.5.3 and Growl 1.1.4) that causes many messages sent by growlnotify to be ignored. The workaround for this is to send network notifications to localhost. The Growl module does this hack automatically; however, you must check "Listen for incoming notifications" under the "Network" tab in the Growl preference pane for these notifications to show up.
# 4. None of the attributes on the Growl module will affect anything concerning Application or Notification objects (unlike how Notifications default to inheriting certain attributes from their parent Application). Think of the module as just holding a single-shot notification.
#
# Currently, setting :udp, :auth, :crypt, :port, :progress or :wait does nothing.
# Network functionality is planned for a later release, but the value of supporting :wait
# at all is debateable. Currently, I have absolutely no clue what 'progress' is supposed to do.

module Growl
  
  PRIORITIES = {:very_low => -2, :moderate => -1, :low => -1, :normal => 0, :high => 1, :very_high => 2, :emergency => 2}
  ATTR_NAMES = [:message, :title, :sticky, :icon, :password, :host, :name, :path, :app_name, :app_icon, :icon_path, :image, :priority, :udp, :auth, :crypt, :wait, :port, :progress, :callback]
  attr_accessor :message, :title, :sticky, :icon, :password, :host, :name, :path, :app_name, :udp, :auth, :crypt, :wait, :port, :progress, :callback
  attr_reader   :app_icon, :icon_path, :image, :priority
  alias :msg  :message
  alias :msg= :message=
  @host = "localhost"
  @path = "/usr/local/bin/growlnotify"

  class << self
    
    # Setter for @app_icon. Automatically appends ".app" to the name given (unless the name
    # already ends in ".app") to retain compatibility with Growl versions < 1.1.4.
    def app_icon=(name)
      @app_icon = self.app_icon_for(name)
    end
  
    # Setter for @icon_path. Automatically expands the path given.
    # Remember, Growl will use the _icon_ of the file that you point to; if you set icon_path
    # to point to an image file, Growl will show the image file's icon, and not the image itself.
    def icon_path=(path)
      @icon_path = File.expand_path(path)
    end
  
    # Setter for @image. Automatically expands the path given.
    def image=(path)
      @image = File.expand_path(path)
    end
  
    # Setter for @priority. Accepts integers between -2 and 2 or priority names as symbols (e.g.
    # :very_low, :moderate, :normal, :high, :emergency).
    def priority=(value)
      @priority = self.priority_for(value)
    end
  
    # Catch-all attribute reader.
    def [](attribute)
      self.instance_variable_get :"@#{attribute}"
    end
  
    # Catch-all attribute setter. Massages data just like described in other setters (for example,
    # automatically appends ".app" to the name when setting Growl[:app_icon]).
    def []=(attribute, value)
      self.instance_variable_set(:"@#{attribute}", transmogrify(attribute, value)) if ATTR_NAMES.include?(attribute)
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
    # a usable attribute.
    def set_defaults!(attrs = {})
      attrs.each do |key, value|
        self[key] = value if ATTR_NAMES.include?(key)
      end
      self
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


    protected

    # Appends ".app" to the application name if it isn't already there. This is no longer
    # necessary with Growl >= 1.1.4, but adding it doesn't hurt and allows compatibility
    # with earlier versions.
    def app_name_for(name)
      name =~ /.*\.app$/ ? name : name + ".app"    
    end
  
    # Converts priority symbol names to integers. Returns 0 if the name isn't found.
    def priority_for(sym)
      PRIORITIES[sym] || 0
    end
  
    # Intelligently transforms simple inputs for :app_icon, :image, and :priority
    # into what growlnotify expects.
    def transmogrify(attribute, value)
      return case attribute
      when :app_icon
        self.app_name_for(value)
      when :icon_path
        value ? File.expand_path(value) : nil
      when :image
        value ? File.expand_path(value) : nil
      when :priority
        value.is_a?(Numeric) ? value : self.priority_for(value)
      else
        value
      end
    end
  
    # Builds the actual command string that is passed to growlnotify.
    def build_message_string(overrides = {})
      overrides.each { |key, value| overrides[key] = transmogrify(key, value) }
      options = self.get_defaults.merge(overrides)
      str = []
      str << "-s"                            if (options[:sticky] || options[:callback])
      str << "-w"                            if (options[:wait]   || options[:callback])
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
      if options[:callback]
        str << "; ruby -e \"#{options[:callback]}\""
      end
      str.join(" ")
    end
  end

  # Default error for anything that goes wrong with a Growl::Application.
  class GrowlApplicationError < StandardError
  end
  
  # Default error for anything that goes wrong with a Growl::Notification.
  class GrowlMessageError < StandardError
  end
end