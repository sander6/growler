require 'objc'

module Growl
  
  # A Ruby class representing an Objective-C GrowlApplicationBridgeDelegate.
  #
  # Setting a GrowlApplicationBridgeDelegate as a delegate to the GrowlApplicationBridge allows for
  # communication between the two. The Growl::ApplicationBridgeDelegate goes a further step and
  # connects to a Growl::Application, which allows callbacks to be caught and sent back to actual
  # Ruby code, without all that tedious mucking around in Objective-C.
  #
  # Calling Growl::ApplicationBridgeDelegate.build and passing a Growl::Application instance will
  # link the two together. Then calling set! on the ApplicationBridgeDelegate instance will set it
  # as a delegate to the GrowlApplicationBridge. When the delegate receives a callback from Growl,
  # it will send a message back to the Growl::Application it was initialized for.
  #
  # You can define the behavior for these callbacks by calling define_callback! on the Application
  # instance. There are three:
  # * :ready - called when Growl starts. Will not be called if the delegate is set when Growl is already running.
  # * :onclick - called when a notification is clicked.
  # * :ontimeout - called when a notification times out.
  class ApplicationBridgeDelegate < ObjC::NSObject
    property :allNotifications, :defaultNotifications, :name, :icon
    attr  :application
    
    # Instantiates a new Growl::ApplicationBridgeDelegate object and feeds it the attributes of
    # the Growl::Application it was built for.
    def self.build(application)
      delegate = self.alloc
      name = ObjC::NSString.stringWithString_(application.name)
      icon = application.icon.TIFFRepresentation if application.icon.respond_to?(:TIFFRepresentation)
      all_notifications = ObjC::NSArray.arrayWithArray_(application.all_notifications)
      default_notifications = ObjC::NSArray.arrayWithArray_(application.default_notifications)
      delegate.initWithName_icon_allNotifications_defaultNotifications_(name, icon, all_notifications, default_notifications)
      delegate.instance_variable_set(:@application, application)
      return delegate
    end
    
    # Sets this object as a delegate of the GrowlApplicationBridge, allowing communication between
    # the two.
    def set!
      Growl::ApplicationBridge.setGrowlDelegate_(self)
    end
    
    imethod "init" do
      super
      self
    end
    
    imethod "initWithName:icon:allNotifications:defaultNotifications:", "v@:@@@@" do |name, icon, all, default|
      self.init
      self.name = ObjC::NSString.stringWithString_(name)
      self.icon = icon.TIFFRepresentation if icon.respond_to?(:TIFFRepresentation)
      self.allNotifications = ObjC::NSArray.arrayWithArray_(all)
      self.defaultNotifications = ObjC::NSArray.arrayWithArray_(default)
      self
    end
    
    imethod "registrationDictionaryForGrowl", "@@:" do
      ns_dict = {"GROWL_NOTIFICATIONS_ALL" => self.allNotifications, "GROWL_NOTIFICATIONS_DEFAULT" => self.defaultNotifications}
      ObjC::NSDictionary.dictionaryWithDictionary_(ns_dict)
    end
    
    imethod "applicationNameForGrowl", "@@:" do
      self.name
    end
    
    imethod "applicationIconDataForGrowl", "@@:" do
      self.icon
    end
    
    imethod "growlIsReady", "v@:" do
      @application.__send__(:growl_is_ready)
    end
    
    imethod "growlNotificationWasClicked:", "v@:i" do
      @application.__send__(:growl_notification_was_clicked)
    end
    
    imethod "growlNotificationTimedOut:", "v@:i" do
      @application.__send__(:growl_notification_timed_out)
    end
    
  end
  
end