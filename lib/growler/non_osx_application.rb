module Growl

  # An alternate definition for the Growl::Application class for non-OSX machines. Functionality
  # is limited to remote registration on other Macs and sending notifications to be posted remotely,
  # but otherwise building and manipulating the application should be just the same.
  #
  # The main differences between a Cocoa-powered Growl::Application and this kind are that setting
  # icons and pids do nothing, it can't be set as a GrowlApplicationBridgeDelegate, and there are no
  # callbacks.
  class NonOSXApplication
    include Growl::Network::Application
    include Enumerable

    REQUIRED_ATTRIBUTE_NAMES = [:name, :all_notifications, :default_notifications]
    attr_accessor :name, :ready_callback, :host, :password
    attr_reader :icon, :all_notifications, :default_notifications, :pid, :registered
    alias_method :registered?, :registered
    
    # Creates a new Growl::Application instance.
    def initialize(attributes = {})
      @name = attributes[:name]
      @host = attributes[:host]
      @password = attributes[:password]
      @pid = $$
      @all_notifications = []
      @default_notifications = []
    end

    # Registers this application remotely with the host provided.
    def register!(host = @host, password = @password)
      @socket = UDPSocket.open
      @socket.connect host, Growl::UDP_PORT
      send_data! build_registration_packet(password)
    end
    
    # Growl::Application includes the Enumerable module to iterate over its notifications.
    def each(&block)
      @all_notifications.each(&block)
    end
       
    # Searches this applications all-notifications list for a notification of the given
    # name and posts it to the given host. You can pass a hash of overrides that get sent
    # to the post method. You can pass the hostname either as the second argument, or as
    # option key :to or :host. You can pass the host's password as either the third argument
    # or option key :password.
    #
    # These two lines do the same thing:
    #   app.post "Some Notification", "some.host", "somepassword", :message => "Hooray!"
    #   app.post "Some Notification", :to => "some.host", :password => "somepassword", :message => "Hooray!"
    #
    # Aliased as notify.
    def post(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      notification_name = args[0]
      host = args[1] || options[:to] || options[:host]
      password = args[2] || options[:password]
      notification = get_notification_by_name(notification_name)
      notification.post(host, password, options) if notification
    end
    alias_method :notify, :post

    # Returns the notification with the given name from this application's all_notifications
    # list, or nil if it isn't found.
    def get_notification_by_name(notification_name)
      detect {|n| n.name == notification_name}
    end
    alias_method :[], :get_notification_by_name
    
    # Creates a new Growl::Notification instance, sets self to that instance's parent application
    # (which defines certain defaults for that notification, such as application name),
    # yields that new notification to the supplied block, and then adds it to this application's
    # all notifications list. Returns the newly created notification object.
    # 
    #   app = Growl::Application.new
    #   app.notification do |note|
    #     note.title = "Process Complete"
    #     note.message = "Your process has finished."
    #     ...
    #   end
    #
    # Remember that with network notifications on non-OSX platforms, you can't specify the icon.
    # So don't try, or all kinds of crazy errors will crop up.
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
          
  end
end