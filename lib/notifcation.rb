require 'osx/cocoa'

module Growl  
  class Notification
    PRIORITIES = {:very_low => -2, :low => -1, :normal => 0, :high => 1, :very_high => 2}
    ATTRIBUTES = [:name, :app_name, :title, :message, :icon, :sticky, :priority, :parent_application]
    attr_reader ATTRIBUTES
    alias :sticky? :sticky
    
    # Catch-all attribute reader. Basically an alias for +instance_variable_get+.
    def [](attribute)
      instance_variable_get :"@#{attribute}"
    end
    
    # Catch-all attribute setter; massages certain inputs to accomodate what Cocoa is looking for.
    # Basically an alias for +instance_variable_set+.
    def []=(attribute, value)
      instance_variable_set :"@#{attribute}", transmogrify(attribute, value)
    end
    
    # Sets attributes of a message from a hash. Used internally when +initialize+ is called.
    # Can be used publically to set multiple attributes at a time.
    def set_attributes(attributes = {})
      attributes.each do |key, value|
        self[key] = value
      end
      self
    end
    
    # Returns a hash of the attributes of the message.
    # Only returns :name, :app_name, :title, :message, :icon, :sticky, :priority, and :parent_application;
    # other bogus attributes that might have been set (i.e. using #[]) will not be returned in the hash.
    def get_attributes
      attributes = {}
      ATTRIBUTES.each do |attribute|
        attributes[attribute] = self[attribute]
      end
      return attributes
    end
    
    # Initializes a new Growl::Notification instance. All necessary instance attributes are read from the
    # attributes on application_parent or have sensible defaults, so +Growl::Notification.new+ with no
    # arguments should return a valid (albeit boring) notification object ready to be posted.
    def initialize(parent_application, attributes = {})
      defaults = {:parent_application => parent_application,
                  :app_name => parent_application.name,
                  :name => parent_application.default_notifications.first,
                  :icon => parent_application.icon,
                  :sticky => false,
                  :priority => 0,
                  :message => "",
                  :title => ""}
      self.set_attributes(defaults.merge(attributes))
    end
    
    # Pass-through name-setter. Returns self so that the pass-through methods can be chained.
    def name(name)
      @name = name
      self
    end

    # Pass-through app_name-setter. Returns self so that the pass-through methods can be chained.    
    def app_name(name)
      @app_name = name
    end

    # Pass-through title-setter. Returns self so that the pass-through methods can be chained.    
    def title(title)
      @title = title
      self
    end

    # Pass-through message-setter. Returns self so that the pass-through methods can be chained.        
    def message(msg)
      @message = msg
      self
    end
    alias :msg :message

    # Pass-through icon-setter. Returns self so that the pass-through methods can be chained.
    # Currently, this method expects an OSX::NSData object as an argument. This is being worked
    # on so that a more sensible datatype can be passed and handled correctly. 
    def icon(name)
      @icon = transmogrify(:icon, name)
      self
    end
    
    # Pass-through sticky-setter. Returns self so that the pass-through methods can be chained.
    def sticky(bool)
      @sticky = bool
      self
    end

    # Pass-through priority-setter. Returns self so that the pass-through methods can be chained.
    # Accepts either priority names as symbols (:very_low, :low, :normal, :high, or :very_high) or
    # integers bewteen -2 and 2.
    def priority(value)
      @priority = transmogrify(:priority, value)
      self
    end
    
    # Posts the message.
    # A hash of overrides can be passed to change the behavior of the output without changing the
    # object's attributes.
    # While you can theoretically override the message's app_name and name, doing so without first
    # having registered an application with that app_name having a (default) message of that name
    # will result in no message getting posted. This could possibly be useful to make one message
    # masquerade as if sent by a different program, should you ever want to.
    def post(overrides = {})
      raise Growl::GrowlMessageError, "No parent application given!" unless @parent_application
      name      = @name     || overrides[:name]                   || ""
      app_name  = @app_name || overrides[:app_name]               || ""
      title     = @title    || overrides[:title]                  || ""
      message   = @message  || overrides[:message]                || ""
      icon      = @icon     || transmogrify(overrides[:icon])     || OSX::NSData.data
      sticky    = @sticky   || overrides[:sticky]                 || false
      priority  = @priority || transmogrify(overrides[:priority]) || 0
      data = {"NotificationName"        => name,
              "ApplicationName"         => app_name,
              "NotificationTitle"       => title,
              "NotificationDescription" => message,
              "NotificationIcon"        => icon,
              "NotificationSticky"      => OSX::NSNumber.numberWithBool(sticky),
              "NotificationPriority"    => OSX::NSNumber.numberWithInt(priority)}
      attrs = OSX::NSDictionary.dictionaryWithDictionary(data)
      OSX::NSDistributedNotificationCenter.defaultCenter.postNotificationName_object_userInfo_deliverImmediately("GrowlNotification", nil, attrs, true)
    end
    alias :notify :post

    # Posts the message with +:sticky => true+.
    def pin(overrides = {})
      post(overrides.merge({:sticky => true}))
    end
    alias :stick :pin
    
    protected
    
    # Massages data to fit expected datatypes.
    def transmogrify(attribute, value)
      return case attribute
      when :icon
        transmogrify_icon(value)
      when :priority
        transmogrify_priority(value)
      else
        nil
      end
    end
    
    # Currently just returns blank OSX::NSData. This makes Growl use the system default application icon.
    # Will eventually try to take an application name or image path as input and use that.
    def transmogrify_icon(icon)
      OSX::NSData.data
    end
    
    # Converts priority symbol names to their integer counterparts.
    # Rewards idiots who pass invalid priority arguments by setting a sensible default instead of raising
    # an exception.
    def transmogrify_priority(value)
      if value.kind_of?(Symbol)
        return PRIORITIES[value]
      elsif value.kind_of?(Integer) && (-2..2).include?(value)
        return value
      else
        return 0
      end
    end
  end
end