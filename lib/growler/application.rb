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
  class Application < OSX::NSObject
    include Growl::ImageExtractor
    include Growl::Returning
    include Enumerable
    
    PROTECTED_ATTRIBUTES = [:all_notifications, :default_notifications, :pid, :registered]
    REQUIRED_ATTRIBUTE_NAMES = [:name, :icon, :all_notifications, :default_notifications]
    attr_accessor :name
    attr_reader   :icon, :all_notifications, :default_notifications, :pid, :nsdnc_identifier, :registered
    alias :registered? :registered

    # I'll admit that I don't fully understand this line, but it seems like it's here to ensure
    # that you're always talking to the same object instance whenever callbacks are flying
    # back and forth.
    # @application = OSX::NSApplication.sharedApplication
    

    # Creates a new Growl::Application instance.
    def initialize(attributes = {})
      # self.set_attributes!(attributes)
      @application = OSX::NSApplication.sharedApplication
      @pid = OSX::NSProcessInfo.processInfo.processIdentifier
      return self
    end

    # Registers this application with Growl (if it has all required attributes, as checked by registerable?).
    # Returns true if registration was attempted, or false if it wasn't. Tapping into Objective-C from Ruby
    # is pretty dark magic, so a return value of true doesn't guarantee that everything will work.
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
    # all your messages. However, there's no downside to registering an application multiple times: it
    # simply get rewritten (note that the notification lists get totally rewritten and not merged).
    def register!
      if registerable?
        registration_data = {"ApplicationName"      => @name,
                             "AllNotifications"     => @all_notifications.collect {|n| n.name},
                             "DefaultNotifications" => @default_notifications.collect {|n| n.name},
                             "ApplicationIcon"      => @icon.TIFFRepresentation}
        ns_dict = OSX::NSDictionary.dictionaryWithDictionary(registration_data)
        ns_note_center = OSX::NSDistributedNotificationCenter.defaultCenter
        ns_name = OSX::NSString.stringWithString("GrowlApplicationRegistrationNotification")
        ns_note_center.postNotificationName_object_userInfo_deliverImmediately_(ns_name, nil, ns_dict, true)
      end
      @registered = registerable?
    end

    def observe!
      nsdnc = OSX::NSDistributedNotificationCenter.defaultCenter
      nsdnc.addObserver_selector_name_object(self, "ready:", nsdnc_identifier_for(:ready), nil)
      nsdnc.addObserver_selector_name_object(self, "clicked:", nsdnc_identifier_for(:clicked), nil)
      nsdnc.addObserver_selector_name_object(self, "timed_out:", nsdnc_identifier_for(:timed_out), nil)
    end
    
    # When (or if) this application receives the GrowlIsReady event, it will invoke this method
    # and register itself with Growl.
    def ready(return_data)
      register! unless registered?
    end
    
    # When a notification that has a callback is clicked, this application receives a message,
    # looks through its @all_notifications for a Notification object of the same name, then
    # calls that Notification's callback.
    # Since callbacks are Notification-specific, you can have different behavior depending on
    # what kind of notification was clicked.
    def clicked(return_data)
      get_notification_from_return_data(return_data).clicked_callback.call
    end
    
    def timed_out(return_data)
      get_notification_from_return_data(return_data).timed_out_callback.call
    end
    
    # --
    # Sets the attributes on this application from a supplied hash. Used internally for initialize,
    # but could also be used publically to set multiple attributes at once.
    #
    # When finished, checks to make sure all required attributes are not nil, and raises a
    # Growl::GrowlApplicationError if any are missing. Returns true on success.
    # def set_attributes!(attributes)
    #   defaults = {:name => "GrowlNotify", :notifications => []}
    #   attributes = defaults.merge(attributes)
    #   @name                  = attributes[:name]
    #   unless attributes[:notifications].empty?
    #     @all_notifications   = add_notifications(attributes[:notifications])
    #   else
    #     @all_notifications   = []
    #   end
    #   @default_notifications = @all_notifications
    #   @icon                  = extract_image_from(attributes)
    #   return self
    # end
    # ++

    # Allows message passing back to this program from OS X; the downside is that it completely
    # locks this thread in a wait-loop. Usability at it's best, it seems.
    def start!
      OSX::NSApp.run
    end
    
    def stop!
      OSX::NSApp.stop(nil)
    end

    # Growl::Application includes the Enumerable module to iterate over its notifications.
    def each(&block)
      @all_notifications.each(&block)
    end
       
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
    def post(name, overrides = {})
      notification = get_notification_by_name(name)
      notification.post(overrides) if notification
    end
    alias :notify :post

    # Returns the notification with the given name from this application's all_notifications
    # list, or nil if it isn't found.
    def get_notification_by_name(notification_name)
      detect {|n| n.name == notification_name}
    end
    alias :[] :get_notification_by_name
    
    # Creates a new Growl::Notification instance, sets self to that instance's parent application
    # (which defines certain defaults for that notification, such as application name and icon),
    # yields that new notification to the supplied block, and then adds it to this application's
    # all notifications list. Returns the newly created notification object.
    # 
    #   app = Growl::Application.new
    #   app.notification do |note|
    #     note.title = "Process Complete"
    #     note.message = "Your process has finished."
    #     ...
    #   end
    def notification
      returning(Growl::Notification.new(self)) do |note|
        yield note
        add_notification note
      end
    end
    
    # Add the notification (as a Growl::Notification object) and adds it to this application's
    # @all_notifications and @default_notifications. Returns the new @all_notifications list.
    #
    # Aliased as add_notification.
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
    alias :add_notification :add_notifications
    
    # Removes the notification from this application's @all_notifications list. Also, naturally,
    # removes it from the @default_notifications. Returns the new @all_notifications list.
    #
    # Aliased as remove_notification.
    def remove_notifications(*notifications)
      notifications.each do |notification|
        self.disable_notification(notification)
        @all_notifications.delete(notification)
      end
      return @all_notifications
    end
    alias :remove_notification :remove_notifications
    
    # Adds the notification to this application's @default_notifications. Returns the new
    # @default_notifications list.
    #
    # Aliased as enable_notification.
    def enable_notifications(*notifications)
      @default_notifications ||= []
      notifications.each do |notification|
        if @all_notifications.include?(notification) && !@default_notifications.include?(notification)
          @default_notifications << notification
        end
      end
      return @default_notifications
    end
    alias :enable_notification :enable_notifications
    
    # Removes the notification from this application's @default_notifications; the notification
    # remains in @all_notifications. Returns the new @default_notifications list.
    #
    # Aliased as disable_notification.
    def disable_notifications(*notifications)
      notifications.each do |notification|
        @default_notifications.delete(notification)
      end
      return @default_notifications
    end
    alias :disable_notification :disable_notifications
    
    # Checks to make sure all required attributes are not nil. If this method returns true, the application
    # has all the attributes it needs to be registered correctly.
    def registerable?
      missing_attributes = REQUIRED_ATTRIBUTE_NAMES.any? do |name|
        self.instance_variable_get(:"@#{name}").nil?
      end
      return !missing_attributes
    end
      
    private

    def get_notification_from_return_data(return_data)
      get_notification_by_name(return_data.userInfo[Growl::GROWL_KEY_CLICKED_CONTEXT].to_s)
    end
    
    def nsdnc_identifier_for(context)
      case context
      when :ready then "#{@name}-#{@pid}-#{Growl::GROWL_IS_READY}"
      when :clicked then "#{@name}-#{@pid}-#{Growl::GROWL_NOTIFICATION_CLICKED}"
      when :timed_out then "#{@name}-#{@pid}-#{Growl::GROWL_NOTIFICATION_TIMED_OUT}"
      end
    end
  end
end