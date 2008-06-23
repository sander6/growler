require 'objc'

module Growl  
  class Notification
    include Growl::ImageExtractor::ObjectiveC
    ATTRIBUTES = [:name, :app_name, :title, :message, :icon, :sticky, :priority]
    ATTRIBUTES.each {|attribute| attr_accessor attribute}
    alias :sticky? :sticky
    
    # Catch-all attribute reader. Basically an alias for instance_variable_get.
    def [](attribute)
      self.instance_variable_get :"@#{attribute}"
    end
    
    # Catch-all attribute setter; massages certain inputs to accomodate what Cocoa is looking for.
    # Basically an alias for instance_variable_set.
    def []=(attribute, value)
      self.instance_variable_set :"@#{attribute}", transmogrify(attribute, value)
    end
    
    # Sets attributes of a message from a hash. Used internally when initialize is called.
    # Can be used publically to set multiple attributes at a time.
    def set_attributes!(attributes = {})
      attributes.each do |key, value|
        self[key] = value if ATTRIBUTES.include?(key)
      end
      @image = extract_image_from(attributes)
      return self
    end
    
    # Returns a hash of the attributes of the message.
    # Only returns :name, :app_name, :title, :message, :icon, :sticky, and :priority; other bogus
    # attributes that might have been set (i.e. using #[]) will not be returned in the hash.
    def get_attributes
      attributes = {}
      ATTRIBUTES.each do |attribute|
        attributes[attribute] = self[attribute]
      end
      return attributes
    end
    
    # Initializes a new Growl::Notification instance. All necessary instance attributes are read from the
    # attributes on application_parent or have sensible defaults, so Growl::Notification.new with no
    # arguments should return a valid (albeit boring) notification object ready to be posted.
    def initialize(*args)
      attributes = args.pop if args.last.is_a?(Hash)
      parent_application = args.shift
      default_app_name  = parent_application ? parent_application.name : ""
      default_name      = parent_application ? parent_application.default_notifications.first : ""
      default_icon      = parent_application ? parent_application.icon : ObjC::NSImage.alloc.init
      defaults = {:app_name => default_app_name,
                  :name => default_name,
                  :icon => default_icon,
                  :sticky => false,
                  :priority => 0,
                  :message => "",
                  :title => ""}
      self.set_attributes!(defaults.merge(attributes))
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
    # Accepts either a priority name as a symbol (:very_low, :moderate, :normal, :high, or
    # :emergency) or an integer bewteen -2 and 2.
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
      name      = @name     || overrides[:name]                   || ""
      app_name  = @app_name || overrides[:app_name]               || ""
      title     = @title    || overrides[:title]                  || ""
      message   = @message  || overrides[:message]                || ""
      icon      = @icon     || transmogrify(overrides[:icon])     || ObjC::NSImage.alloc.init
      sticky    = @sticky   || overrides[:sticky]                 || false
      priority  = @priority || transmogrify(overrides[:priority]) || 0
      data = {"NotificationName"        => name,
              "ApplicationName"         => app_name,
              "NotificationTitle"       => title,
              "NotificationDescription" => message,
              "NotificationIcon"        => icon.TIFFRepresentation,
              "NotificationSticky"      => ObjC::NSNumber.numberWithBool_(sticky),
              "NotificationPriority"    => ObjC::NSNumber.numberWithInt_(priority)}
      attrs = ObjC::NSDictionary.dictionaryWithDictionary_(data)
      ObjC::NSDistributedNotificationCenter.defaultCenter.postNotificationName_object_userInfo_deliverImmediately_("GrowlNotification", nil, attrs, true)
    end
    alias :notify :post

    # Posts the message with :sticky => true.
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
        value
      end
    end
    
    # Currently just returns blank OSX::NSData. This makes Growl use the system default application icon.
    # Will eventually try to take an application name or image path as input and use that.
    def transmogrify_icon(icon)
      ObjC::NSData.data
    end
    
    # Converts priority symbol names to their integer counterparts.
    # Rewards idiots who pass invalid priority arguments by setting a sensible default instead of raising
    # an exception.
    def transmogrify_priority(value)
      if value.kind_of?(Symbol)
        return Growl::PRIORITIES[value] || 0
      elsif value.kind_of?(Integer) && (-2..2).include?(value)
        return value
      else
        return 0
      end
    end
  end
end