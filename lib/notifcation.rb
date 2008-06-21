require 'osx/cocoa'

module Growl
  
  class Notification
    PRIORITIES = {:very_low => -2, :low => -1, :normal => 0, :high => 1, :very_high => 2}
    ATTRIBUTES = [:name, :app_name, :title, :message, :icon, :sticky, :priority, :parent_application]
    attr_reader ATTRIBUTES
    alias :sticky? :sticky
    
    def [](attribute)
      instance_variable_get :"@#{attribute}"
    end
    
    def []=(attribute, value)
      instance_variable_set :"@#{attribute}", transmogrify(attribute, value)
    end
    
    def set_attributes(attributes = {})
      attributes.each do |key, value|
        self[key] = value
      end
      self
    end
    
    def get_attributes
      attributes = {}
      ATTRIBUTES.each do |attribute|
        attributes[attribute] = self[attribute]
      end
      return attributes
    end
    
    def initialize(parent_application, attributes = {})
      defaults = {:parent_application => parent_application,
                  :app_name => parent_application.name,
                  :name => parent_application.default_notifications.first,
                  :icon => parent_application.icon,
                  :sticky => false,
                  :priority => 0}
      self.set_attributes(defaults.merge(attributes))
    end
    
    def name(name)
      @name = name
      self
    end
    
    def app_name(name)
      @app_name = name
    end
    
    def title(title)
      @title = title
      self
    end
    
    def message(msg)
      @message = msg
      self
    end
    alias :msg :message
    
    def icon(name)
      @icon = transmogrify(:icon, name)
      self
    end
    
    def sticky(bool)
      @sticky = bool
      self
    end
    
    def priority(value)
      @priority = transmogrify(:priority, value)
      self
    end
    
    def post(overrides)
      raise GrowlMessageParentError, "No parent application given!" unless @parent_application
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
    
    def pin(overrides)
      post(overrides.merge({:sticky => true}))
    end
    alias :stick :pin
    
    protected
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
    
    # Currently just returns blank OSX::NSData.
    def transmogrify_icon(icon)
      OSX::NSData.data
    end
    
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