require 'osx/cocoa'
require 'fileutils'
require 'yaml'

module Growl

  class Application
    PROTECTED_ATTRIBUTES = [:frozen, :frozen_attributes_path]
    ATTRIBUTE_NAMES = [:name, :icon, :all_notifications, :default_notifications, :registered]
    DEFAULT_ATTRIBUTES = {:name => "Growler",
                          :icon => OSX::NSData.data,
                          :all_notifications => [],
                          :default_notifications => [],
                          :registered => false}
    NOTIFICATION_CENTER = OSX::NSDistributedNotificationCenter.defaultCenter
    attr_accessor :name, :icon, :all_notifications, :default_notifications
    attr_reader   :registered, :frozen, :frozen_attributes_path
    
    def registered?
      @registered
    end
    
    def frozen?
      @frozen ||= File.exist?(File.expand_path(@frozen_attributes_path))
    end
    
    def [](attribute)
      self.instance_variable_get(:"@#{attribute}")
    end
    
    def []=(attribute, value)
      unless PROTECTED_ATTRIBUTES.include?(attribute)
        self.instance_variable_set(:"@#{attribute}", value)      
      end
    end
    
    def add_notification(notification)
      unless @all_notifications.include?(notification)
        @all_notifications << notification
        @default_notifications << notification
      end
    end
    
    def remove_notification(notification)
      @all_notifications.delete(notification)
    end
    
    def enable_notification(notification)
      if @all_notifications.include?(notification) && !@default_notifications.include?(notification)
        @default_notifications << notification
      end
    end
    
    def disable_notification(notification)
      @default_notifications.delete(notification)
    end
    
    def freeze_attributes!(path = "./growler_config.yaml")
      @frozen_attributes_path = File.expand_path(path)
      if check_for_missing_attributes
        attributes = {:name => @name,
                      :icon => @icon,
                      :all_notifications => @all_notifications,
                      :default_notifications => @default_notifications,
                      :registered => @registered,
                      :frozen_attributes_path => @frozen_attributes_path}
        File.open(@frozen_attributes_path, File::WRONLY|File::TRUNC|File::CREAT, 0666) do |file|
          file.puts(attrs.to_yaml)
        end
        @frozen = true
      end
    end
    
    def unfreeze_attributes!
      FileUtils.rm(@frozen_attributes_path)
      @frozen = false
      return !@frozen
    end
    
    def set_attributes!(attributes)
      ATTRIBUTE_NAMES.each do |key|
        self[key] = attributes[key] if attributes.has_key?(key)
      end
      check_for_missing_attributes
    end
    
    def check_for_missing_attributes
      missing_attributes = ATTRIBUTE_NAMES.collect do |name|
        name if self.instance_variable_get(:"@#{name}").nil?}
      end.compact
      if missing_attributes.empty?
        return true
      else
        raise Growl::GrowlApplicationAttributeError, "Missing required attributes! (#{missing_attributes.join(", ")})"
      end
    end
    
    def initialize(path_or_attributes_hash = nil)
      if path_or_attributes_hash.is_a?(String)
        path = File.expand_path(path_or_attributes_hash)
        if File.exist?(path)
          attributes = File.open(path) {|file| YAML.load(file)}
        else
          raise Growl::GrowlApplicationAttributeError, "No configuration file to load at #{path}!"
        end
      elsif path_or_attributes_hash.is_a?(Hash)
        attributes = path_or_attributes_hash
      else
        attributes = DEFAULT_ATTRIBUTES
      end
      self.set_attributes!(attributes)
    end
    
    def register!
      registration_data = {"ApplicationName" => @name,
                           "AllNotifications" => OSX::NSArray.arrayWithArray(@all_notifications.collect(&:name)),
                           "DefaultNotifications" => OSX::NSArray.arrayWithArray(@default_notifications.collect(&:name)),
                           "ApplicationIcon" => @icon}
      attrs = OSX::NSDictionary.dictionaryWithDictionary(registration_data)
      name = "GrowlApplicationRegistrationNotification"
      NOTIFICATION_CENTER.postNotificationName_object_userInfo_deliverImmediately(name, nil, attrs, true)
      @registered = true
    end
  end

end