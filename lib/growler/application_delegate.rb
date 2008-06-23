require 'objc'

module Growl
  
  class ApplicationBridgeDelegate < ObjC::NSObject
    property :allNotifications, :defaultNotifications, :name, :icon
    attr  :application
    
    def self.build(application)
      delegate = self.alloc
      delegate.initWithName_icon_allNotifications_defaultNotifications_(application[:name], application[:icon], application[:all_notifications], application[:default_notifications])
      delegate.instance_variable_set(:@application, application)
      return delegate
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
      @application.__send__(:growl_id_ready_callback)
    end
    
    imethod "growlNotificationWasClicked:", "v@:i" do
      @application.__send__(:growl_notification_was_clicked_callback)
    end
    
    imethod "growlNotificationTimedOut:", "v@:i" do
      @application.__send__(:growl_notification_timed_out_callback)
    end
    
  end
  
end