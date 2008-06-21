module Growl
  # For simple scripts it's easier to just send one-off notifications without going through the
  # rigmarole of setting configuration and registering the application. For the times when that
  # would be overkill, the +Growl+ module itself can be used to send simple notifications.
  #
  # Unlike +Growl::Notification+, which taps into the Cocoa bindings for Growl, the +Growl+
  # module simply wraps the +growlnotify+ command-line utility. You might find that this is
  # more convenient and powerful, since it's simple and has a much easier time with custom
  # notification icons.
  #
  # To use, set your messages attributes on the +Growl+ module directly, using about the same
  # syntax and attribute names as you would for a +Growl::Notification+, then call +Growl.post+
  # to post the message. 
  #
  # Some things to be aware of:
  #   1. You can set the name of the application the +Growl+ module posts as, but the notification
  #   won't show up unless that application has already been registered. The default application
  #   name is "growlnotify", so change those settings to alter how the +Growl+ module's
  #   notifications appear. The same holds true for notification names.
  #   2. You cannot register the +Growl+ module as an application. However, by setting the
  #   application name of the +Growl+ module (+Growl[:name] = name+) to that of an already-
  #   registered application (either one you made using Growler or one from somewhere else),
  #   the notifications send by the module will inherit the settings for that application as
  #   defined in the Growl preference pane.
  #   3. There is a bug in Leopard (still persists in Leopard 10.5.3 and Growl 1.1.4) that
  #   causes many messages sent by +growlnotify+ to be ignored. The workaround for this
  #   is to send network notifications to localhost. The +Growl+ module does this hack automatically;
  #   however, you must check "Listen for incoming notifications" under the "Network" tab in
  #   the Growl preference pane for these notifications to show up.
  #   4. None of the attributes on the +Growl+ module will affect anything concerning +Application+
  #   or +Notification+ objects (unlike how +Notifications+ default to inheriting certain
  #   attributes from their parent +Application+). Think of the module as just holding a
  #   single-shot notification.
  #
  # Currently, setting +:udp+, +:auth+, +:crypt+, +:port+, +:progress+ or +:wait+ does nothing.
  # Network functionality is planned for a later release, but the value of supporting +:wait+
  # at all is debateable. Currently, I have absolutely no clue what 'progress' is supposed to do.
  
  PRIORITIES = {:very_low => -2, :low => -1, :normal => 0, :high => 1, :very_high => 2}
  ATTR_NAMES = [:message, :title, :sticky, :icon, :password, :host, :name, :path, :app_name, :app_icon, :icon_path, :image, :priority, :udp, :auth, :crypt, :wait, :port, :progress]
  attr_accessor :message, :title, :sticky, :icon, :password, :host, :name, :path, :app_name, :udp, :auth, :crypt, :wait, :port, :progress
  attr_reader   :app_icon, :icon_path, :image, :priority
  alias :msg :message
  @host = "localhost"
  @path = "/usr/local/bin/growlnotify"

  # Setter for +@app_icon+. Automatically appends ".app" to the name given (unless the name
  # already ends in ".app") to retain compatibility with Growl versions < 1.1.4.
  def self.app_icon=(name)
    @app_icon = self.app_icon_for(name)
  end
  
  # Setter for +@icon_path+. Automatically expands the path given.
  # Remember, Growl will use the _icon_ of the file that you point to; if you set +icon_path+
  # to point to an image file, Growl will show the image file's icon, and not the image itself.
  def self.icon_path=(path)
    @icon_path = File.expand_path(path)
  end
  
  # Setter for +@image+. Automatically expands the path given.
  def self.image=(path)
    @image = File.expand_path(path)
  end
  
  # Setter for +@priority+. Accepts integers between -2 and 2 or priority names as symbols (e.g.
  # :very_low, :low, :normal, :high, :very_high).
  def self.priority=(value)
    @priority = self.priority_for(value)
  end
  
  # Catch-all attribute reader.
  def self.[](attribute)
    self.instance_variable_get :"@#{attribute}"
  end
  
  # Catch-all attribute setter. Massages data just like described in other setters (for example,
  # automatically appends ".app" to the name when setting +Growl[:app_icon]+).
  def self.[]=(attribute, value)
    self.instance_variable_set(:"@#{attribute}", transmogrify(attribute, value)) if ATTR_NAMES.include?(attribute)
  end

  # Returns a hash of the current settings.
  def self.get_defaults
    attributes = {}
    ATTR_NAMES.each do |attribute|
      attributes[attribute] = self[attribute]
    end
    return attributes
  end

  # Mass attribute setter. Pass attributes as a hash; returns self. Ignores any keys that aren't
  # a usable attribute.
  def self.set_defaults!(attrs = {})
    attrs.each do |key, value|
      self[key] = value if ATTR_NAMES.include?(key)
    end
    self
  end

  # Posts a notification based on the current module settings.
  # Pass a hash of override attributes to alter the notification being posted without changing
  # any attributes on the module.
  #
  # Calls +growlnotify+ using +%x[]+, so returns STDOUT from the shell. If there are no glaring
  # errors in syntax, usually returns "". However, a return value of "" is no guarantee that
  # the message actually showed up on the screen. If notifications aren't showing up, read the
  # notes about "things to be aware of" at the top and see if those fix the problem.
  #
  # Aliased as +notify+.
  def self.post(overrides = {})
    %x[#{@path} #{self.build_message_string(overrides)}]
  end
  alias :notify :post

  # Just like +post+ with automatic :sticky => true.
  #
  # Aliased as +stick+.
  def self.pin(overrides = {})
    post(overrides.merge(:sticky => true))
  end
  alias :stick :pin 
  
  # Sends the same message to each of the hosts specified.
  # Send hosts and passwords as arrays.
  # Example Growl.broadcast(["some.host", "pass"], ["some.other.host", "word"], ...)
  def self.broadcast(*hosts)
    hosts.each {|*host| self.post(:host => host[0], :password => host[1])}
  end


  protected

  # Appends ".app" to the application name if it isn't already there. This is no longer
  # necessary with Growl >= 1.1.4, but adding it doesn't hurt and allows compatibility
  # with earlier versions.
  def self.app_name_for(name)
    name =~ /.*\.app$/ ? name : name + ".app"    
  end
  
  # Converts priority symbol names to integers. Returns 0 if the name isn't found.
  def self.priority_for(sym)
    PRIORITIES[sym] || 0
  end
  
  # Intelligently transforms simple inputs for :app_icon, :image, and :priority
  # into what growlnotify expects.
  def self.transmogrify(attribute, value)
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
  
  # Builds the actual command string that is passed to +growlnotify+.
  def self.build_message_string(overrides = {})
    # default_sticky    = overrides[:sticky]    || @sticky
    # default_app_name  = overrides[:app_name]  || @app_name
    # default_name      = overrides[:name]      || @name
    # default_message   = overrides[:message]   || overrides[:msg]    || @message
    # default_icon      = overrides[:icon]      || @icon
    # default_icon_path = overrides[:icon_path] || @icon_path
    # default_image     = overrides[:image]     || @image
    # default_app_icon  = overrides[:app_icon]  || @app_icon
    # default_priority  = overrides[:priority]  || @priority
    # default_host      = overrides[:host]      || @host
    # default_title     = overrides[:title]     || @title
    
    options = self.get_defaults.merge(overrides)

    str = []
    str << "-s"                            if options[:sticky]
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

  class GrowlApplicationError < StandardError
  end
  
  class GrowlMessageError < StandardError
  end
end