require 'osx/cocoa'

module Growl
  
  # A Growl::Application instance holds information about your program (the one you're using Growler
  # with) and makes registering your application with Growl easy. The advantages of registering your
  # application are that your users can define custom display behavior for your application and its
  # notifications, without broadly affecting other notifications' display behaviors. Contrast this
  # with simply posting messages using the Growl module (which, by default, is tied into the 'growlnotify'
  # command line application), which will always use the display settings for the 'growlnotify'
  # application (unless, of course, you choose to masquerade the Growl module as some other application;
  # see Growl module documentation for details).
  #
  # Growl::Applications can be built and registered by calling Growl.build_application and passing it
  # a block defining the attributes. There are two required attributes, @name and @icon. @name can be
  # set directly with the name= setter method, but Growl is expecting @icon to be an NSConcreteData
  # object. The methods on applications allow you to set this icon with the same ease as you would
  # using growlnotify.
  #
  # An example of setting up a new application:
  #
  #   growler = Growl.application do |app|
  #     app.name = "My Program's Name"
  #     app.app_icon = "Terminal"
  #     app.notification do |note|
  #       note.name = "Finished Processing"
  #       note.message = "Your process has completed."
  #     end
  #   end
  #
  # Using build_application will automatically register your application with Growl. There is no harm
  # or significant load associated with reregistering an application. Therefore, defining this block
  # in some part of your application where it will always be initialized will make sure that your
  # application is registered and ready to deliver notifications each time your application runs.
  #
  # An example of posting an application's notification:
  #
  #   growler["Finished Processing"].post
  #
  # Growl::Application also includes the Enumerable module to iterate over notifications.
  class Application
    include Growl::ImageExtractor
    include Growl::Returning
    include Enumerable

    # Growl::Application includes the Enumerable module to iterate over its notifications.
    def each(&block)
      @all_notifications.each(&block)
    end
    
    PROTECTED_ATTRIBUTES = [:registered, :registerable, :all_notifications, :default_notifications]
    REQUIRED_ATTRIBUTE_NAMES = [:name, :icon, :all_notifications, :default_notifications]
    attr_accessor :name
    attr_reader   :icon, :registered, :all_notifications, :default_notifications, :registerable
    alias :registered?    :registered
    alias :registerable?  :registerable
    
    # Setter for @icon; expects a OSX::NSImage object as an argument.
    def image=(img)
      @icon = img
    end
    
    # Setter for @icon. Takes a path to an image file and sets the default notification icon
    # for this application to that image.
    def image_path=(path)
      @icon = image_from_image_path(path)
    end
    
    # Setter for @icon. Takes a path to a file and sets the default notification icon for this
    # application to the icon of that file. Note that even if the file at the supplied path
    # is an image, will use that file's icon (e.g. the default .jpg icon) and not the image
    # itself. Use image_path= if you want to contents of the image.
    def icon_path=(path)
      @icon = image_from_icon_path(path)
    end
    
    # Setter for @icon. Takes a file type extension (such as "rb" or "txt") and sets the default
    # notification icon for this application to the default system icon for that file type.
    def file_type=(type)
      @icon = image_from_file_type(type)
    end
    
    # Setter for @icon. Takes the name of an application (such as "TextMate" or "Firefox") and
    # sets the default notification icon for this application to that application's icon.
    def app_icon=(name)
      @icon = image_from_app_icon(name)
    end
    
    # Searches this applications all-notifications list for a notification of the given
    # name and posts it. You can pass a hash of overrides that get sent to the post method.
    def notify_by_name(name, overrides = {})
      notification = detect {|n| n[:name] == name}
      notification.post(overrides) if notification
    end
    alias :post_by_name :notify_by_name
    
    # Posts the notification at the given index within this application's all-notifications
    # list. Can pass :first, :last, or :random to post the first, the last, or a random
    # notification, should you ever want to. You can pass a hash of overrides that get sent to
    # the post method on that notification.
    def notify_by_index(index_or_symbol, overrides = {})
      if index_or_symbol.is_a?(Symbol)
        index = case index_or_symbol
                when :first   then 0
                when :last    then -1
                when :random  then rand(self.all_notifications.size)
                end
        notification = all_notifications[index]
        notification.post(overrides) if notification
      end
    end
    alias :post_by_index :notify_by_index
   
    # Returns the notification in this application's all_notifications with the given name, or creates
    # a new one with the given name if one wasn't found.
    #
    # Note that creating a new notification this way does not inform Growl about it (call register!
    # to do that), so attempting to post that notification will fail until the application is
    # (re)registered.
    def [](name_or_index)
      if name_or_index.is_a?(String)
        msg = detect { |n| n.name == name_or_index }
      elsif name.is_a?(Integer)
        msg = @all_notifications[name_or_index]
      end
      return msg
    end
    
    # Creates a new Growl::Notification instance, sets self to that instance's parent application
    # (which defines certain defaults for that notification, such as application name and icon),
    # yields that new notification to the supplied block, and then adds it to this application's
    # all notifications list. Returns the newly created notification object.
    # 
    # This is a less compact yet more overt way to create notifications for your applications.
    # For example, you could use new_notification and pass attributes as a hash:
    #
    #   app = Growl::Application.new
    #   app.new_notification(:title => "Process Complete", :message => "Your process has finished.", ...)
    #
    # or use build_notification to set attributes using the setter methods in a block syntax, which
    # some people find more appealing or easier to understand:
    #
    #   app = Growl::Application.new
    #   app.notification do |note|
    #     note.title = "Process Complete"
    #     note.message = "Your process has finished."
    #     ...
    #   end
    #
    # See also new_notification for alternate syntax.
    def notification
      returning(Growl::Notification.new(self)) do |note|
        yield note
        add_notifications note
      end
    end
    
    # Add the notification (as a Growl::Notification object) and adds it to this application's
    # @all_notifications and @default_notifications. Returns nil on failure (if the notification
    # already existed), else returns the notification.
    #
    # Adds this application as the Notification's @parent_application, effectively stealing it
    # from the previous parent (if any).
    #
    # Aliased as add_message.
    def add_notifications(*notifications)
      @all_notifications ||= []
      notifications.each do |notification|
        unless @all_notifications.include?(notification)
          @all_notifications << notification
          self.enable_notification(notification)
        end
      end
      return @all_notifications
    end
    alias :add_messages :add_notifications
    
    # Removes the notification from this application's @all_notifications list. Also, naturally,
    # removes it from the @default_notifications. Returns the removed notification, or nil if it
    # wasn't found.
    #
    # Aliased as remove_message.
    def remove_notification(notification)
      self.disable_notification(notification)
      @all_notifications.delete(notification)
    end
    alias :remove_message :remove_notification
    
    # Adds the notification to this application's @default_notifications. Returns nil on failure
    # (if the notification was already in defaults, or it was not in @all_notifications).
    #
    # Aliased as enable_message.
    def enable_notification(notification)
      @default_notifications ||= []
      if @all_notifications.include?(notification) && !@default_notifications.include?(notification)
        @default_notifications << notification
      else
        return nil
      end
    end
    alias :enable_message :enable_notification
    
    # Removes the notification from this application's @default_notifications; the notification
    # remains in @all_notifications. Returns the deleted notification, or nil if it wasn't found.
    #
    # Aliased as disable_message.
    def disable_notification(notification)
      @default_notifications.delete(notification)
    end
    alias :disable_message :disable_notification
    
    # Sets the attributes on this application from a supplied hash. Used internally for initialize,
    # but could also be used publically to set multiple attributes at once.
    #
    # When finished, checks to make sure all required attributes are not nil, and raises a
    # Growl::GrowlApplicationError if any are missing. Returns true on success.
    def set_attributes!(attributes)
      @name                   =   attributes[:name]
      @all_notifications      =   add_notifications(attributes[:notifications]) if attributes[:notifications]
      if attributes[:disabled_notifications] && attributes[:disabled_notifications].is_a?(Array)
        @default_notifications  =   @all_notifications - attributes[:disabled_notifications]
      else
        @default_notifications  =   @all_notifications
      end
      @icon                   =   extract_image_from(attributes)
      @registerable           =   check_for_missing_attributes
      return self
    end
            
    # Creates a new Growl::Application instance with attributes supplied by a hash.
    def initialize(attributes = {})
      self.set_attributes!(attributes)
      return self
    end
    
    # Registers this application with Growl.
    #
    # After registration, you'll be able to open the Growl Preference Pane and set the desired behavior for
    # notifications from this application, such as default display styles (which I believe is impossible
    # to do via scripting).
    #
    # It's important to note that attempting to post a notification (i.e. calling post on a Growl::Notification
    # instance) will not work unless that notification is from a registered application and that notification's
    # name is in that application's all-notifications list.
    #
    # Therefore, it's best to register! your application after setting all your attributes and defining
    # all your messages. However, there's no downside to registering an application multiple times (it
    # simply get rewritten).
    def register!
      registration_data = {"ApplicationName"      => @name,
                           "AllNotifications"     => @all_notifications.collect {|n| n[:name]},
                           "DefaultNotifications" => @default_notifications.collect {|n| n[:name]},
                           "ApplicationIcon"      => @icon.TIFFRepresentation}
      ns_dict = OSX::NSDictionary.dictionaryWithDictionary(registration_data)
      ns_note_center = OSX::NSDistributedNotificationCenter.defaultCenter
      ns_name = OSX::NSString.stringWithString("GrowlApplicationRegistrationNotification")
      ns_note_center.postNotificationName_object_userInfo_deliverImmediately_(ns_name, nil, ns_dict, true)
      @registered = true
    end
    
    protected    

    # Checks to make sure all required attributes are not nil. If this method returns true, the application
    # has all the attributes it needs to be registered correctly.
    def check_for_missing_attributes
      missing_attributes = REQUIRED_ATTRIBUTE_NAMES.collect do |name|
        name if self.instance_variable_get(:"@#{name}").nil?
      end.compact
      return !missing_attributes.empty?
    end

  end
end