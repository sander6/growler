module Growl  
  class Notification
    include Growl::ImageExtractor
    include Growl::PriorityExtractor
    include Growl::Network::Notification
    
    WR_ATTRIBUTES = [:app_name, :title, :sticky, :remote_host, :password]
    RO_ATTRIBUTES = [:name, :message, :icon, :priority]
    ATTRIBUTES = WR_ATTRIBUTES + RO_ATTRIBUTES
    WR_ATTRIBUTES.each { |a| attr_accessor  a }
    RO_ATTRIBUTES.each { |a| attr_reader    a }
    attr_reader :parent, :pid, :clicked_callback, :timed_out_callback
    alias_method :sticky?, :sticky
   
    # Initializes a new Growl::Notification instance. Pass a Growl::Application object to act as
    # this notification's "parent" and/or a hash of attributes for this notifications. Will set
    # the following defaults if you don't specify them:
    # * :app_name - name of the application passed as the parent, or "growlnotify"
    # * :name - "Command-Line Growl Notification"
    # * :image - icon of parent application, unless :image_path, :icon_path, :file_type, or :app_icon was also passed
    # * :sticky - false
    # * :message - ""
    # * :title - ""
    def initialize(*args)
      attributes = args.last.is_a?(Hash) ? args.pop : {}
      @parent = args[0]
      if @parent && @parent.is_a?(Growl::Application)
        @app_name = @parent.name
        @pid = @parent.pid || $$
        @remote_host = @parent.remote_host
        @password = @parent.password
      else
        @app_name = "growlnotify"
      end
      @name = attributes[:name]
      @title = attributes[:title] || @name
      @sticky = attributes[:sticky] || false
      @priority = get_priority_for(attributes[:priority] || 0)
      unless [:image_path, :icon_path, :file_type, :app_icon].any? {|k| attributes.has_key?(k)}
        @icon = @parent ? @parent.icon : nil
      else
        @icon = extract_image_from(attributes)
      end
      @message = DynamicString.new(attributes[:message] || "")
    end

    # The name of the Growl::Application that this notification belongs to.
    def application_name
      @parent.name if @parent
    end
    
    # Catch-all attribute reader. Used internally to mock exposing notification attributes as a
    # Hash, which is clean and convenient syntax; can be used publically if needed.
    #
    # Note that the setter analogue, []=, is protected and its use publically is not advised since
    # it doesn't perform data transformations like the traditional setter methods (attribute=) do.
    def [](attribute)
      self.instance_variable_get("@#{attribute}")
    end
    
    # Returns a hash of the attributes of the message.
    def get_attributes
      attributes = {}
      ATTRIBUTES.each do |attribute|
        attributes[attribute] = self[attribute]
      end
      return attributes
    end
    
    # Setter for the name attribute. Will set this notification's title to the same as its name if the
    # title is not already set. This is advocated by the Growl documentation, since it encourages helpful,
    # descriptive names of notifications.
    def name=(str)
      @name = str
      @title ||= DynamicString.new(@name)
      @name
    end
    
    # Setter for the message attribute. Creates a new DynamicString instance with the given base string
    # and capture pattern. For non-dynamic messages, you need only worry about passing a string to this method.
    # Otherwise, read up about DynamicStrings to see how to make dynamic message templates.
    def message=(*args)
      @message = DynamicString.new(*args)
    end
    
    # Setter for the title. Creates a new DynamicString instance with the given base string and capture
    # pattern. See DynamicString for details on how to use them.
    def title=(*args)
      @title = DynamicString.new(*args)
    end
    
    # Takes a path to an image file and uses that as this notification's icon.
    def image_path=(path)
      @icon = image_from_image_path(path)
    end
    
    # Takes a path to a file and uses that file's icon as this notification's icon. Note that even 
    # if the file at the path you specify is an image, will use that file's icon (e.g. the default
    # .jpg icon) and not the file's contents (use image_path to use the file's contents).
    def icon_path=(path)
      @icon = image_from_icon_path(path)
    end
    
    # Takes a file type extension (such as "rb" or "torrent") and  the default system icon for that
    # file type as this notification's icon.
    def file_type=(type)
      @icon = image_from_file_type(type)
    end
    
    # Takes the name of an application (such as "Safari" or "Quicksilver") and uses that application's
    # icon for this notification's icon.
    def app_icon=(name)
      @icon = image_from_app_icon(name)
    end

    # Accepts either a priority name as a symbol (:very_low, :moderate, :normal, :high, or
    # :emergency) or an integer bewteen -2 and 2 to set this notification's priorty. Keep in mind
    # that the priority of a notification doesn't automatically mean anything; it just allows the
    # end user to customize display settings for notifications with various priorities.
    def priority=(value)
      @priority = get_priority_for(value)
    end
    
    # Posts the message.
    # A hash of overrides can be passed to change the behavior of the output without changing the
    # object's attributes.
    #
    # While you can theoretically override the message's app_name and name, doing so without first
    # having registered an application with that app_name having a (default) message of that name
    # will result in no message getting posted. This could possibly be useful to make one message
    # masquerade as if sent by a different program, should you ever want to.
    #
    # Other keys passed to overrides will be sent to the message and title to be dynamically rendered.
    # See DynamicString for details about this. If both the title and message have a variable of the
    # same name, passing that key will get interpolated into both strings. For (a bogus) example:
    #   msg = Growl::Notification.new(:name => "Files Converted")
    #   msg.title = "{number} Files Converted"
    #   msg.message = "{number} files were successfully converted in {dir}."
    #   ... (application registration and stuff) ...
    #   msg.post(:number => 2, :dir => File.dirname(__FILE__))
    def post(overrides = {})
      Growl.application_bridge.notifyWithDictionary(build_notification_data(overrides))
    end
    alias_method :notify, :post
    
    # Posts this message to the supplied remote host, or the default @remote_host. You can
    # either pass the hostname and password as the first and second arguments, or stick them
    # into the overrides hash as :host, :remote_host, and/or :password.
    def post_to_remote(host = @remote_host, password = @password, overrides = {})
      tmp_host = options[:host] || options[:remote_host] || host
      tmp_password = options[:password] || password
      @socket = UDPSocket.open
      @socket.connect tmp_host, Growl::UDP_PORT
      send_data! build_notification_packet(tmp_password, options)
    end
    alias_method :notify_to_remote, :post_to_remote

    # Posts the message forcing :sticky => true.
    def pin(overrides = {})
      post(overrides.merge({:sticky => true}))
    end
    alias_method :stick, :pin
    
    # Posts the message to the supplied (or default) remote_host with :sticky => true.
    def pin_to_remote(host = @remote_host, password = @password, overrides = {})
      post_to_remote(host, password, overrides.merge({:sticky => true}))
    end
    alias_method :stick_to_remote, :pin_to_remote
    
    # Registers a callback to run when this notification is clicked.
    # Pass a block of the desired behavior. This notification's application
    # and the notification itself will be yielded to the Proc when called.
    # For example:
    #   notification.when_clicked do |application, notification|
    #     puts "Hooray! I got clicked!"
    #   end
    # Or, one actually using the yielded objects:
    #   notification.when_clicked do |application, notification|
    #     application["Something Got Clicked"].post(:clicked_notification => notification.name)
    #   end
    def when_clicked(&block)
      @clicked_callback = block
    end
    
    # Registered a callback to run when this notification times out.
    # Pass a block of the desired behavior. This notification's application
    # and the notification itself will be yielded to the Proc when called.
    # 
    # Arguably less useful than when_clicked.
    def when_timed_out(&block)
      @timed_out_callback = block
    end
    
    # Returns true if this notification has the specified type of callback.
    # The only meaningful values are :clicked and :timed_out, but you could
    # really pass anything you'd like (though those would probably return
    # false).
    def has_callback?(context)
      instance_variable_defined?("@#{context}_callback") 
    end
    
    private

    # Builds the notification hash to send to Growl so that it knows how to post the notification
    # (actually, Growl doesn't keep track of a notification's message body, title, stickiness, 
    # priority, etc., and needs to be send this information each time a notification is posted. 
    # It's Growler that's helping you keep track of all that so you don't have to tediously type
    # out messages and titles each time.).
    def build_notification_data(overrides = {})
      tmp_name      = overrides[:name]                       || @name      || ""
      tmp_app_name  = overrides[:app_name]                   || @app_name  || ""
      tmp_title     = overrides[:title]                      || @title     || ""
      tmp_icon      = extract_image_from(overrides)          || @icon      || OSX::NSImage.alloc.init
      tmp_priority  = get_priority_for(overrides[:priority]) || @priority  || 0
      tmp_message   = overrides[:message]                    || @message.render(overrides)   || ""
      # A more delicate idiom is required for boolean attributes, since || doesn't behave like it does above. 
      tmp_sticky = overrides[:sticky].nil? ? (@sticky.nil? ? false : @sticky) : overrides[:sticky]

      data = {"NotificationName"        => tmp_name,
              "ApplicationName"         => tmp_app_name,
              "NotificationTitle"       => tmp_title,
              "NotificationDescription" => tmp_message,
              "NotificationIcon"        => tmp_icon.TIFFRepresentation,
              "NotificationSticky"      => OSX::NSNumber.numberWithBool_(tmp_sticky),
              "NotificationPriority"    => OSX::NSNumber.numberWithInt_(get_priority_for(tmp_priority))}       
      data.merge!({"ApplicationPID" => @pid}) if @pid
      data.merge!({"NotificationClickContext" => @name}) if @clicked_callback
      data.merge!({"NotificationTimedOutContext" => @name}) if @timed_out_callback
      return OSX::NSDictionary.dictionaryWithDictionary(data)
    end
    
    # Catch-all attribute setter. Used internally; use the other setters to set attributes, since
    # those will transform inputs into the correct types.
    def []=(attribute, value)
      self.instance_variable_set("@#{attribute}", value)
    end
  end
end