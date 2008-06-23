require 'osx/cocoa'
require 'fileutils'
require 'yaml'

module Growl
  class Application
    include Growl::ImageExtractor::ObjectiveC
    PROTECTED_ATTRIBUTES = [:frozen, :frozen_attributes_path, :registered, :registerable, :all_notifications, :default_notifications]
    REQUIRED_ATTRIBUTE_NAMES = [:name, :icon, :all_notifications, :default_notifications]
    attr_accessor :name, :icon
    attr_reader   :registered, :frozen, :frozen_attributes_path, :all_notifications, :default_notifications, :registerable
    alias :messages       :all_notifications
    alias :registered?    :registered
    alias :registerable?  :registerable
    
    # Searches this applications all-notifications list for a notification of the given
    # name and posts it. You can pass a hash of overrides that get sent to the post method.
    def notify_by_name(name, overrides = {})
      all_notifications[all_notifications.collect {|n| n[:name]}.index(name)].post(overrides)
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
    
    # Returns true or false depending on whether this application's attributes have been frozen
    # (that is, written to disk).
    def frozen?
      @frozen ||= File.exist?(File.expand_path(@frozen_attributes_path))
    end

    #--
    # Catch-all attribute-getter.
    # def [](attribute)
    #   self.instance_variable_get(:"@#{attribute}")
    # end
    
    # Catch-all attribute-setter. Doesn't allow one to set protected attributes (those that depend
    # on forces outside the scope of the Ruby application) such as :frozen, :frozen_attributes_path,
    # and :registered.
    # def []=(attribute, value)
    #   unless PROTECTED_ATTRIBUTES.include?(attribute)
    #     self.instance_variable_set(:"@#{attribute}", value)      
    #   end
    # end
    #++
    
    # Returns the notification in this application's all_notifications with the given name, or creates
    # a new one with the given name if one wasn't found.
    #
    # Note that creating a new notification this way does not inform Growl about it (call register!
    # to do that), so attempting to post that notification will fail until the application is
    # (re)registered.
    def [](name)
      msg = all_notifications[all_notifications.collect {|n| n[:name]}.index(name)]
      if msg
        return msg
      else
        return new_notification(self, :name => name)
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
      notifications.each do |notification|
        unless @all_notifications.include?(notification)
          notification[:parent_application] = self
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
    
    # Creates a new Growl::Notification instance with the supplied attributes, sets self to
    # that notification's parent_application, and calls add_notifications on that instance,
    # adding it to this application's @all_notifications and @default_notifications. Returns
    # the new Notification object.
    #
    # Because of the way Growl::Notification objects are initialized, most of the attributes for
    # the message are inherited from the application's attributes, and the rest have sensible
    # yet boring defaults.
    # 
    # Therefore, application.new_notification without any arguments should make a perfectly
    # valid (albeit boring) message, ready to be posted. 
    #
    # Because of the ease of use, this is the preferred way to create new Notification objects.
    #
    # See Growl::Notification.new for information on notification initialization, such as the
    # defaults.
    #
    # Aliased as new_message.
    def new_notification(attributes = {})
      msg = Growl::Notification.new(self, attributes)
      self.add_notifications(msg)
      return msg
    end
    alias :new_message :new_notification
    
    # This method is currently in transition and can't be relied upon to do anything.
    #
    # Freezes the current attributes by writing them to a YAML file at the path specified.
    # Returns true on success.
    #
    # This allows a measure of persistence to your Growl configuration, since this YAML file
    # can be loaded up and used to initialize a Growl::Application object. Therefore, you
    # needn't go through the tedious process of declaring all your Application attributes
    # every time, provided you have your desired attributes frozen somewhere.
    # def freeze_attributes!(path = "./growler_config.yaml")
    def freeze_attributes!(path = "./config.growl")
      @frozen_attributes_path = File.expand_path(path)
      if check_for_missing_attributes
        attributes = {:name => @name,
                      :icon => @icon,
                      :all_notifications => @all_notifications,
                      :default_notifications => @default_notifications,
                      :registered => @registered,
                      :registerable => @registerable,
                      :frozen => true,
                      :frozen_attributes_path => @frozen_attributes_path}
        File.open(@frozen_attributes_path, File::WRONLY|File::TRUNC|File::CREAT, 0666) do |file|
          file.puts(Marshal.dump(attributes))
        end
        @frozen = true
      end
      return @frozen
    end
    
    # This method is currently in transition and can't be relied upon to do anything.
    #
    # Unfreezes attributes by tossing out the YAML file that was written with freeze_attributes!.
    # Raises an exception if the YAML file isn't found. Returns true on success.
    def unfreeze_attributes!
      FileUtils.rm(@frozen_attributes_path)
      @frozen = false
      return !@frozen
    end
    
    # Sets the attributes on this application from a supplied hash. Used internally for initialize,
    # but could also be used publically to set multiple attributes at once.
    #
    # When finished, checks to make sure all required attributes are not nil, and raises a
    # Growl::GrowlApplicationError if any are missing. Returns true on success.
    def set_attributes!(attributes)
      @name                   =   attributes[:name]
      @all_notifications      =   add_notifications(attributes[:notifications])
      @default_notifications  =   @all_notifications - attributes[:disabled_notifications]
      @icon                   =   extract_image_from(attributes)
      @registerable           =   check_for_missing_attributes
      return self
    end
            
    # Creates a new Growl::Application instance.
    # Pass either the path to a pre-existing set of frozen attributes or a hash of new attributes
    # to set; otherwise will use the Growl::Application::DEFAULT_ATTRIBUTES.
    def initialize(path_or_attributes_hash = nil)
      if path_or_attributes_hash.is_a?(String)
        path = File.expand_path(path_or_attributes_hash)
        attributes = load_attributes_from_file(path)
      elsif path_or_attributes_hash.is_a?(Hash)
        attributes = path_or_attributes_hash
      else
        attributes = {}
      end
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
      all_notification_names = @all_notifications.collect {|n| n[:name]}
      ns_all_notification_list = ObjC::NSArray.arrayWithArray_(all_notification_names)
      default_notification_names = @default_notifications.collect {|n| n[:name]}
      ns_default_notification_list = ObjC::NSArray.arrayWithArray_(default_notification_names)
      ns_app_name = ObjC::NSString.stringWithString_(@name)
      ns_icon = @icon.TIFFRepresentation
      registration_data = {"ApplicationName"      => ns_app_name,
                           "AllNotifications"     => ns_all_notification_list,
                           "DefaultNotifications" => ns_default_notification_list,
                           "ApplicationIcon"      => ns_icon}
      ns_dict = ObjC::NSDictionary.dictionaryWithDictionary_(registration_data)
      ns_note_center = ObjC::NSDistributedNotificationCenter.defaultCenter
      ns_name = ObjC::NSString.stringWithString_("GrowlApplicationRegistrationNotification")
      ns_note_center.postNotificationName_object_userInfo_deliverImmediately_(ns_name, nil, ns_dict, true)
      @registered = true
    end
    
    # Instantiates a new Growl::ApplicationBridgeDelegate linked to this Application. When the
    # (actual) GrowlApplicationBridge sends a callback to the delegate, will, in turn, call a
    # callback on this Application. There are events that trigger callbacks:
    # * :ready - called with Growl is launched. Is not called if the delegate is set while Growl is already running.
    # * :onclick - called when a notification is clicked.
    # * :ontimeout - called when a notification times out.
    #
    # These callbacks can be set by calling define_callback!
    def build_delegate!
      Growl::ApplicationBridgeDelegate.build(self)
    end
    
    # Defines a callback to run on certain events. The types are:
    # * :ready - called with Growl is launched. Is not called if the delegate is set while Growl is already running.
    # * :onclick - called when a notification is clicked.
    # * :ontimeout - called when a notification times out.
    #
    # These callbacks take no arguments.
    def define_callback!(type, &method)
      case type
      when :ready
        self.__send__(:define_method, :growl_is_ready, &method)
      when :onclick
        self.__send__(:define_method, :growl_notification_was_clicked, &method)
      when :ontimeout
        self.__send__(:define_method, :growl_notification_timed_out, &method)
      else
        raise Growl::GrowlApplicationError, "Invalid callback type! (must be :ready, :onclick, or :ontimeout)"
      end
    end
    
    # Creates a new Growl::Application instance and set it's attributes either from a supplied
    # hash, or by reading a YAML file at the provided location.
    #
    # First, looks for a YAML file at the path provided. If found, initializes a new Application
    # object from the attributes read from that file. Otherwise, will initialize the object
    # from the attributes hash provided.
    #
    # Will call add_notifications on the Growl::Notification objects passed as the
    # :notifications key of the attributes hash, effectively adding this application as each of
    # those messages parent_application, and adding those notifications to this application's
    # all-notifications list. Will _not_ do this if the application already has notifications
    # (i.e. if it was restored from a frozen attributes file).
    #
    # Will then freeze the attributes unless they are already frozen.
    #
    # Finally, will register the application unless it is already registered or there are no
    # notifications.
    #
    # Returns the Application object created.
    #
    # Why all this rigmarole? With this one call, you can initialize or continue a Growl::Application
    # instance over multiple restarts of your program. Put this call in your program's initialization
    # file, or wherever it'll get run each time your program loads, and set a constant/global to catch
    # the output, and you'll have consistent, reusable Growl notification support throughout your program.    
    def self.initialize_or_load_attributes_from_file(path, attributes)
      path = File.expand_path(path)

      application = File.exist?(path) ? self.new(path) : self.new(attributes)

      notifications = attributes.delete(:notifications)
      if notifications && application.all_notifications.empty?
        application.add_notifications(notifications)
      end

      application.freeze_attributes!(path) unless application.frozen?

      application.register! unless (application.registered? || application.all_notifications.empty?)

      return application
    end
    
    protected    

    # Checks to make sure all required attributes are not nil. If this method returns true, the application
    # has all the attributes it needs to be registered correctly.
    def check_for_missing_attributes
      missing_attributes = ATTRIBUTE_NAMES.collect do |name|
        name if self.instance_variable_get(:"@#{name}").nil?
      end.compact
      return !missing_attributes.empty?
    end
    
    # This method is currently in transition and can't be relied upon to do anything.
    #
    # Reads Application attributes from a YAML file; used internally for persisting configuration
    # settings across program restarts. Raises Growl::GrowlApplicationError if no file is found
    # at path.
    def load_attributes_from_file(path)
      if File.exist?(path)
        # return File.open(path) {|file| YAML.load(file)}
        return File.open(path) {|file| Marshal.load(file)}
      else
        raise Growl::GrowlApplicationError, "No configuration file to load at #{path}!"
      end
    end
    
    private
    
    # Null growlIsReady callback.
    def growl_is_ready; end
    
    # Null growlNotificationWasClicked callback.
    def growl_notification_was_clicked; end
    
    # Null growlNotificationTimedOut callback.
    def growl_notification_timed_out; end
  end
end