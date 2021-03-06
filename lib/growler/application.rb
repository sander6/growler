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
  # Growl::Applications can be built and registered by calling Growl.application and passing it
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
  # Using application will automatically register your application with Growl and tell the Notification
  # Center to start observing it for callbacks. There is no harm or significant load associated with
  # reregistering an application. Therefore, defining this block in some part of your application where
  # it will always be initialized will make sure that your application is registered and ready to deliver
  # notifications each time your application runs.
  #
  # An example of posting an application's notification:
  #
  #   growler["Finished Processing"].post
  #
  # Growl::Application also includes the Enumerable module to iterate over notifications.
  class Application < OSX::NSObject
    include Growl::ImageExtractor
    include Growl::Network::Application
    include Enumerable

    REQUIRED_ATTRIBUTE_NAMES = [:name, :icon, :all_notifications, :default_notifications]
    attr_accessor :name, :ready_callback, :remote_host, :password
    attr_reader :icon, :all_notifications, :default_notifications, :pid, :registered
    alias_method :registered?, :registered
    
    # Creates a new Growl::Application instance.
    # Note that since Growl::Applications inherit from NSObject, it has a janky initialize method
    # that can't take any arguments. Therefore you'll have to create the object first and then
    # set it's attributes with the attribute setters (easily done with Growl.application).
    def initialize
      @application = OSX::NSApplication.sharedApplication
      @pid = $$
      @all_notifications = []
      @default_notifications = []
      @remote_host = nil
      @password = nil
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
      Growl.application_bridge.registerWithDictionary(build_registration_dictionary) if registerable?
      @registered = registerable?
    end
    
    def register_with_remote!(host = @remote_host, password = @password)
      @socket = UDPSocket.open
      @socket.connect host, Growl::UDP_PORT
      send_data! build_registration_packet(password)
    end
    
    # Sets this application as a GrowlApplicationBridgeDelegate, allowing it to communicate with Growl.
    def set_as_delegate!
      Growl.application_bridge.setGrowlDelegate(self)
    end
    
    # When (or if) this application receives the GrowlIsReady event, it will invoke this method
    # and register itself with Growl. If the application has a @ready_callback, will call it
    # yielding self.
    def ready(return_data)
      register! unless registered?
      @ready_callback.call(self) if @ready_callback
    end
    alias_method :growlIsReady, :ready

    # Registers a callback to run when this application receives the GrowlIsReady event, in
    # addition to registering the application if it isn't already. Yields itself to the Proc
    # when called.
    # For example, to post a notification when ready:
    #   application.on_ready do |app|
    #     app.post("Ready")
    #   end
    #
    # The GrowlIsReady event triggers if this application is running when Growl starts. However,
    # most of the time starting up Growler while Growl is off causes RubyCocoa to seg-fault.
    # Therefore this method is pretty useless right now, but when that gets fixed it'll start to
    # mean something.
    def on_ready(&block)
      @ready_callback = block
    end
    
    # When a notification that has a callback is clicked, this application receives a message,
    # looks through its @all_notifications for a Notification object of the same name, then
    # calls that Notification's callback.
    # Since callbacks are Notification-specific, you can have different behavior depending on
    # what kind of notification was clicked.
    def clicked(return_data)
      notification = get_notification_by_name(return_data)
      notification.clicked_callback.call(self, notification) if notification.has_callback?(:clicked)
    end
    alias_method :growlNotificationWasClicked, :clicked
    
    # When a notification times out, Growl will notify this application with the name of that 
    # notification and pass it to the timed_out method. The application will search its
    # @all_notifications list for that notification and run its timed_out_callback.
    # Since callbacks are Notification-specific, you can have different behavior depending on
    # what kind of notification timed out.
    def timed_out(return_data)
      notification = get_notification_by_name(return_data)
      notification.timed_out_callback.call(self, notification) if notification.has_callback?(:timed_out)
    end
    alias_method :growlNotificationTimedOut, :timed_out


    # Allows message passing back to this program from OS X; the downside is that it completely
    # locks this thread in a wait-loop. Usability at its best, it seems.
    def start!
      OSX::NSApp.run
    end
    
    # Stops the main loop that allows message-passing from this application to and from Growl.
    # This method is added for completeness to stop an application after calling start! on it,
    # but since start! locks this thread endlessly, this method is practically useless.
    #
    # If I find a way to unblock the NSApp.run loop, this method will start to mean something.
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
    
    # Growl delegate method to get the name of this application.
    def applicationNameForGrowl
      @name
    end
    
    # Growl delegate method to get the icon data of this application.
    def applicationIconDataForGrowl
      @icon.TIFFRepresentation if @icon && @icon.is_a?(OSX::NSImage)
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
    
    # Searches this application's all_notifications list for a notification of the given
    # name and posts it. You can pass a hash of overrides that get sent to the post method.
    def post(name, overrides = {})
      notification = get_notification_by_name(name)
      notification.post(overrides) if notification
    end
    alias_method :notify, :post
    
    # Searches this application's all_notifications list for a notification of the given
    # name and posts it remotely to the supplied host, or to the default remote_host. You
    # can pass a hash of overrides that get send to the post method; you can also set the
    # host and password with override keys :host and :password.
    def post_to_remote(name, host = @remote_host, password = @password, overrides = {})
      notification = get_notification_by_name(name)
      notification.post_to_remote(host, password, overrides) if notification
    end
    alias_method :notify_to_remote, :post

    # Returns the notification with the given name from this application's all_notifications
    # list, or nil if it isn't found.
    def get_notification_by_name(notification_name)
      detect {|n| n.name == notification_name}
    end
    alias_method :[], :get_notification_by_name
    
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
    alias_method :add_notification, :add_notifications
    
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
    alias_method :remove_notification, :remove_notifications
    
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
    alias_method :enable_notification, :enable_notifications
    
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
    alias_method :disable_notification, :disable_notifications
    
    # Checks to make sure all required attributes are not nil. If this method returns true, the application
    # has all the attributes it needs to be registered correctly.
    def registerable?
      REQUIRED_ATTRIBUTE_NAMES.collect { |name| self.send(name) }.all?
    end
    
    # Creates the registration dictionary to send to Growl for this application to get registered.
    def build_registration_dictionary
      OSX::NSDictionary.dictionaryWithDictionary({
        "ApplicationName"      => @name,
        "ApplicationId"        => @pid,
        "AllNotifications"     => @all_notifications.collect {|n| n.name},
        "DefaultNotifications" => @default_notifications.collect {|n| n.name},
        "ApplicationIcon"      => @icon.TIFFRepresentation
      })
    end
    alias_method :registrationDictionaryForGrowl, :build_registration_dictionary
      
    private

    # When this application receives a signal from Growl that a message was clicked or timed out,
    # this method searches for that notification in this application's all_notifications list.
    def get_notification_from_return_data(return_data)
      get_notification_by_name(return_data.to_ruby)
    end
  end
end