require 'osx/cocoa'

module Growl  
  class Notification
    include Growl::ImageExtractor
    include Growl::PriorityExtractor
    
    ATTRIBUTES = [:name, :app_name, :title, :message, :icon, :sticky, :priority]
    ATTRIBUTES.each { |a| attr_accessor a }
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
        default_app_name = @parent.name
        @pid = @parent.pid || $$
      else
        default_app_name = "growlnotify"
      end
      default_name = "Command-Line Growl Notification"
      unless [:image_path, :icon_path, :file_type, :app_icon].any? {|k| attributes.has_key?(k)}
        default_icon = @parent ? @parent.icon : nil
      else
        default_icon = nil
      end
      defaults = {:app_name => default_app_name,
                  :name => default_name,
                  :image => default_icon,
                  :sticky => false,
                  :priority => 0,
                  :message => "",
                  :title => ""}
      set_attributes!(defaults.merge(attributes))
      return self
    end

    # The name of the Growl::Application that this notification belongs to.
    def application_name
      @parent.name
    end
    
    # Catch-all attribute reader. Used internally to mock exposing notification attributes as a
    # Hash, which is clean and convenient syntax; can be used publically if needed.
    #
    # Note that the setter analogue, []=, is protected and its use publically is not advised since
    # it doesn't perform data transformations like the traditional setter methods (attribute=) do.
    def [](attribute)
      self.instance_variable_get("@#{attribute}")
    end
    
    # Sets attributes of a message from a hash. Used internally when initialize is called.
    # Can be used publically to set multiple attributes at a time.
    # def set_attributes!(attributes = {})
    #   attributes.each do |key, value|
    #     self[key] = value if ATTRIBUTES.include?(key)
    #   end
    #   @icon = extract_image_from(attributes)
    #   return self
    # end
    
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
      @title ||= @name
      @name
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
    # You can also pass a block to define this Notification's click callback behavior. However, doing
    # so will overwrite any behavior you have already defined.
    #
    # While you can theoretically override the message's app_name and name, doing so without first
    # having registered an application with that app_name having a (default) message of that name
    # will result in no message getting posted. This could possibly be useful to make one message
    # masquerade as if sent by a different program, should you ever want to.
    def post(overrides = {})
      Growl.application_bridge.notifyWithDictionary(build_notification_data(overrides))
    end
    alias_method :notify, :post

    # Posts the message forcing :sticky => true.
    def pin(overrides = {})
      post(overrides.merge({:sticky => true}))
    end
    alias_method :stick, :pin
    
    # Registers a callback to run when this notification is clicked.
    # Pass a block of the desired behavior. For example:
    #   notification.when_clicked do
    #     puts "Hooray! I got clicked!"
    #   end
    def when_clicked(&block)
      @clicked_callback = block
    end
    
    # Registered a callback to run when this notification times out.
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

    def build_notification_data(overrides = {})
      tmp_name      = overrides[:name]                       || @name      || ""
      tmp_app_name  = overrides[:app_name]                   || @app_name  || ""
      tmp_title     = overrides[:title]                      || @title     || ""
      tmp_message   = overrides[:message]                    || @message   || ""
      tmp_icon      = extract_image_from(overrides)          || @icon      || OSX::NSImage.alloc.init
      tmp_priority  = get_priority_for(overrides[:priority]) || @priority  || 0
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