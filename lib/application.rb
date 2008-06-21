require 'osx/cocoa'
require 'fileutils'
require 'yaml'

module Growl
  class Application
    PROTECTED_ATTRIBUTES = [:frozen, :frozen_attributes_path, :registered, :all_notifications, :default_notifications]
    ATTRIBUTE_NAMES = [:name, :icon, :all_notifications, :default_notifications]
    DEFAULT_ATTRIBUTES = {:name => "Growler",
                          :icon => OSX::NSData.data,
                          :all_notifications => [],
                          :default_notifications => [],
                          :registered => false}
    NOTIFICATION_CENTER = OSX::NSDistributedNotificationCenter.defaultCenter
    attr_accessor :name, :icon
    attr_reader   :registered, :frozen, :frozen_attributes_path, :all_notifications, :default_notifications
    alias :messages     :all_notifications
    alias :registered?  :registered
    
    # Searches this applications all-notifications list for a notification of the given
    # name and posts it.
    def notify_by_name(name)
      all_notifications[all_notifications.collect {|n| n[:name]}.index(name)].post
    end
    alias :post_by_name :notify_by_name
    
    # Posts the notification at the given index within this application's all-notifications
    # list. Can pass :first, :last, or :random to post the first, the last, or a random
    # notification, should you ever want to.
    def notify_by_index(index_or_symbol)
      if index_or_symbol.is_a?(Symbol)
        index = case index_or_symbol
                when :first   then 0
                when :last    then -1
                when :random  then rand(self.all_notifications.size)
                end
        notification = all_notifications[index]
        notification.post if notification
      end
    end
    alias :post_by_index :notify_by_index
    
    # Returns true or false depending on whether this application's attributes have been frozen
    # (that is, written to disk).
    def frozen?
      @frozen ||= File.exist?(File.expand_path(@frozen_attributes_path))
    end
    
    # Catch-all attribute-getter.
    def [](attribute)
      self.instance_variable_get(:"@#{attribute}")
    end
    
    # Catch-all attribute-setter. Doesn't allow one to set protected attributes (those that depend
    # on forces outside the scope of the Ruby application) such as :frozen, :frozen_attributes_path,
    # and :registered.
    def []=(attribute, value)
      unless PROTECTED_ATTRIBUTES.include?(attribute)
        self.instance_variable_set(:"@#{attribute}", value)      
      end
    end
    
    # Add the notification (as a +Growl::Notification+ object) and adds it to this application's
    # +@all_notifications+ and +@default_notifications+. Returns nil on failure (if the notification
    # already existed), else returns the notification.
    #
    # Adds this application as the +Notification+'s +@parent_application+, effectively stealing it
    # from the previous parent (if any).
    #
    # Aliased as +add_message+.
    def add_notification(notification)
      unless @all_notifications.include?(notification)
        notification[:parent_application] = self
        @all_notifications << notification
        @default_notifications.enable_notification(notification)
        return notification
      else
        return nil
      end
    end
    alias :add_message :add_notification
    
    # Removes the notification from this application's +@all_notifications+ list. Also, naturally,
    # removes it from the +@default_notifications+. Returns the removed notification, or nil if it
    # wasn't found.
    #
    # Aliased as +remove_message+.
    def remove_notification(notification)
      @default_notifications.disable_notification(notification)
      @all_notifications.delete(notification)
    end
    alias :remove_message :remove_notification
    
    # Adds the notification to this application's +@default_notifications+. Returns nil on failure
    # (if the notification was already in defaults, or it was not in +@all_notifications+).
    #
    # Aliased as +enable_message+.
    def enable_notification(notification)
      if @all_notifications.include?(notification) && !@default_notifications.include?(notification)
        @default_notifications << notification
      else
        return nil
      end
    end
    alias :enable_message :enable_notification
    
    # Removes the notification from this application's +@default_notifications+; the notification
    # remains in +@all_notifications+. Returns the deleted notification, or nil if it wasn't found.
    #
    # Aliased as +disable_message+.
    def disable_notification(notification)
      @default_notifications.delete(notification)
    end
    alias :disable_message :disable_notification
    
    # Creates a new +Growl::Notification+ instance with the supplied attributes, sets +self+ to
    # that notification's +parent_application+, and calls +add_notification+ on that instance,
    # adding it to this application's +@all_notifications+ and +@default_notifications+. Returns
    # the new +Notification+ object.
    #
    # Because of the way +Growl::Notification+ objects are initialized, most of the attributes for
    # the message are inherited from the application's attributes, and the rest have sensible
    # yet boring defaults.
    # 
    # Therefore, +application.new_notification+ without any arguments should make a perfectly
    # valid (albeit boring) message, ready to be posted. 
    #
    # Because of the ease of use, this is the preferred way to create new +Notification+ objects.
    #
    # See +Growl::Notification.new+ for information on notification initialization, such as the
    # defaults.
    #
    # Aliased as +new_message+.
    def new_notification(attributes = {})
      msg = Growl::Message.new(self, attributes)
      self.add_notification(msg)
      return msg
    end
    alias :new_message :new_notification
    
    # Freezes the current attributes by writing them to a YAML file at the +path+ specified.
    # Returns true on success.
    #
    # This allows a measure of persistence to your Growl configuration, since this YAML file
    # can be loaded up and used to initialize a +Growl::Application+ object. Therefore, you
    # needn't go through the tedious process of declaring all your Application attributes
    # every time, provided you have your desired attributes frozen somewhere.
    def freeze_attributes!(path = "./growler_config.yaml")
      @frozen_attributes_path = File.expand_path(path)
      if check_for_missing_attributes
        attributes = {:name => @name,
                      :icon => @icon,
                      :all_notifications => @all_notifications,
                      :default_notifications => @default_notifications,
                      :registered => @registered,
                      :frozen => true,
                      :frozen_attributes_path => @frozen_attributes_path}
        File.open(@frozen_attributes_path, File::WRONLY|File::TRUNC|File::CREAT, 0666) do |file|
          file.puts(attrs.to_yaml)
        end
        @frozen = true
      end
      return @frozen
    end
    
    # Unfreezes attributes by tossing out the YAML file that was written with +freeze_attributes!+.
    # Raises an exception if the YAML file isn't found. Returns true on success.
    def unfreeze_attributes!
      FileUtils.rm(@frozen_attributes_path)
      @frozen = false
      return !@frozen
    end
    
    # Sets the attributes on this application from a supplied hash. Used internally for +initialize+,
    # but could also be used publically to set multiple attributes at once.
    #
    # When finished, checks to make sure all required attributes are not nil, and raises a
    # +Growl::GrowlApplicationError+ if any are missing. Returns true on success.
    def set_attributes!(attributes)
      ATTRIBUTE_NAMES.each do |key|
        self.instance_variable_set(:"@#{key}", attributes[key]) if attributes.has_key?(key)
      end
      check_for_missing_attributes
    end
    
    # Unfreezes attributes if frozen and resets attributes to the built-it defaults, as defined
    # in the +Growl::Application::DEFAULT_ATTRIBUTES+ constant.
    def reset_defaults!
      unfreeze_attributes! if frozen?
      set_attributes!(DEFAULT_ATTRIBUTES)
    end
        
    # Creates a new +Growl::Application+ instance.
    # Pass either the path to a pre-existing set of frozen attributes or a hash of new attributes
    # to set; otherwise will use the +Growl::Application::DEFAULT_ATTRIBUTES+.
    def initialize(path_or_attributes_hash = nil)
      if path_or_attributes_hash.is_a?(String)
        path = File.expand_path(path_or_attributes_hash)
        attributes = load_attributes_from_file(path)
      elsif path_or_attributes_hash.is_a?(Hash)
        attributes = path_or_attributes_hash
      else
        attributes = DEFAULT_ATTRIBUTES
      end
      self.set_attributes!(attributes)
      self
    end
    
    # Registers this application with Growl.
    #
    # After registration, you'll be able to open the Growl Preference Pane and set the desired behavior for
    # notifications from this application, such as default display styles (which I believe is impossible
    # to do via scripting).
    #
    # It's important to note that attempting to post a notification (i.e. calling +post+ on a +Growl::Notification+
    # instance) will not work unless that notification is from a registered application and that notification's
    # name is in that application's all-notifications list.
    #
    # Therefore, it's best to +register!+ your application after setting all your attributes and defining
    # all your messages. However, there's no downside to registering an application multiple times (it
    # simply get rewritten).
    def register!
      registration_data = {"ApplicationName" => @name,
                           "AllNotifications" => OSX::NSArray.arrayWithArray(@all_notifications.collect {|n| n[:name]}),
                           "DefaultNotifications" => OSX::NSArray.arrayWithArray(@default_notifications.collect {|n| n[:name]}),
                           "ApplicationIcon" => @icon}
      attrs = OSX::NSDictionary.dictionaryWithDictionary(registration_data)
      OSX::NSDistributedNotificationCenter.defaultCenter.postNotificationName_object_userInfo_deliverImmediately("GrowlApplicationRegistrationNotification", nil, attrs, true)
      @registered = true
    end
    
    # Creates a new +Growl::Application+ instance and set it's attributes either from a supplied
    # hash, or by reading a YAML file at the provided location.
    #
    # First, looks for a YAML file at the path provided. If found, initializes a new +Application+
    # object from the attributes read from that file. Otherwise, will initialize the object
    # from the attributes hash provided.
    #
    # Will call +add_notification+ on each +Growl::Notification+ object passed as the
    # :notifications key of the attributes hash, effectively adding this application as each of
    # those messages +parent_application+, and adding those notifications to this application's
    # all-notifications list. Will _not_ do this if the application already has notifications
    # (i.e. if it was restored from a frozen attributes file).
    #
    # Will then freeze the attributes unless they are already frozen.
    #
    # Finally, will register the application unless it is already registered or there are no
    # notifications.
    #
    # Returns the +Application+ object created.
    #
    # Why all this rigmarole? With this one call, you can initialize or continue a +Growl::Application+
    # instance over multiple restarts of your program. Put this call in your program's initialization
    # file, or wherever it'll get run each time your program loads, and set a constant/global to catch
    # the output, and you'll have consistent, reusable Growl notification support throughout your program.    
    def self.initialize_or_load_attributes_from_file(path, attributes)
      path = File.expand_path(path)

      application = File.exist?(path) ? self.new(path) : self.new(attributes)

      notifications = attributes.delete(:notifications)
      if notifications && application.all_notifications.empty?
        notifications.each do |notification|
          application.add_notification(notification)
        end
      end

      application.freeze_attributes!(path) unless application.frozen?

      application.register! unless (application.registered? || application.all_notifications.empty?)

      return application
    end
    
    protected    

    # Checks to make sure all required attributes are not nil. Raises +Growl::GrowlApplicationError+
    # if any attributes are missing. Otherwise returns true.
    def check_for_missing_attributes
      missing_attributes = ATTRIBUTE_NAMES.collect do |name|
        name if self.instance_variable_get(:"@#{name}").nil?}
      end.compact
      if missing_attributes.empty?
        return true
      else
        raise Growl::GrowlApplicationError, "Missing required attributes! (#{missing_attributes.join(", ")})"
      end
    end
    
    # Reads +Application+ attributes from a YAML file; used internally for persisting configuration
    # settings across program restarts. Raises +Growl::GrowlApplicationError+ if no file is found
    # at +path+.
    def load_attributes_from_file(path)
      if File.exist?(path)
        return File.open(path) {|file| YAML.load(file)}
      else
        raise Growl::GrowlApplicationError, "No configuration file to load at #{path}!"
      end
    end
  end
end