require 'osx/cocoa'
require 'yaml'
require 'fileutils'

module Growl
  class GrowlApplicationError < StandardError
  end
  
  class GrowlMessageError < StandardError
  end
end

class Symbol
  def to_proc
    Proc.new {|*args| agrs.shift.__send__(self, *args)}
  end
end

class Growl
  PROTECTED_CATTRS = [:frozen]

  # Whereby 'cattr', I mean an instance variable (attribute) on the class instance, not
  # actually a class variable (class attribute).
  def self.[](cattr)
    self.instance_variable_get :"@#{cattr}"
  end
  
  def self.[]=(cattr, value)
    self.instance_variable_set(:"@#{cattr}", value) unless PROTECTED_CATTRS.include?(cattr)
  end
  
  def initialize(message = "", options = {})
    defaults = {:host => Growl[:host], :message => message, :priority => 0}
    options = defaults.merge(options)
    Growl.add_notification(options[:name])
    set_attributes(options)
  end
    
  # Catch-all attribute reader.
  def [](attribute)
    self.instance_variable_get :"@#{attribute}"
  end
  
  # Catch-all attribute setter.
  def []=(attribute, value)
    self.instance_variable_set :"@#{attribute}", transmogrify(attribute, value)
  end

  # Mass attribute reader. Returns attributes as a hash.
  def get_attributes
    attrs = {}
    ATTR_NAMES.each do |key|
      attrs[key] = self[key]
    end
    attrs      
  end
  
  # Mass attribute setter. Pass attributes as a hash; returns the new attribute hash.
  def set_attributes(attrs = {})
    attrs.each do |key, value|
      self[key] = value
    end
    get_attributes
  end

  def message(message)
    @message = message
    self
  end
  alias :msg :message
  
  def title(title)
    @title = title
    self
  end
  
  def sticky(sticky)
    @sticky = sticky
    self
  end
  
  def icon(icon)
    @icon = icon
    self
  end
  
  def icon_path(path)
    @icon_path = File.expand_path(path)
    self
  end
  
  def priority(value)
    @priority = value.to_priority
    self
  end
  alias :pri :priority
  
  def app_icon(app_name)
    @app_icon = app_name.to_app_name
    self
  end
  
  def image(path)
    @image = File.expand_path(path)
    self
  end

  def password(pwd)
    @password = pwd if pwd
    self
  end
  
  def host(host)
    @host = host
    self
  end
  
  def name(name)
    @name = name
    self
  end
  
  def sticky?
    @sticky
  end
  
  def post(overrides = {})
    # cli_only_attrs? ? post_using_cli : post_using_cocoa
    post_using_cocoa(overrides)
  end
  alias :notify :post

  def stick(overrides = {})
    # cli_only_attrs? ? stick_using_cli : stick_using_cocoa
    stick_using_cocoa(overrides)
  end
  # For those of us who think 'stick' is too close to 'sticky'
  alias :pin :stick
  
  # Sends the same message to each of the hosts specified.
  # Send hosts and passwords as arrays.
  # Example @growl.broadcast(["some.host", "pass"], ["some.other.host", "word"])
  def broadcast(*hosts)
    original_host = self[:host]
    orginal_password = self[:password]
    hosts.each {|*host| self.host(host[0]).password(host[1]).post}
    self[:host] = original_host
    self[:password] = orginal_password
  end

  HERE = File.dirname(File.expand_path(__FILE__))
  PRIORITIES = {:very_low => -2, :low => -1, :regular => 0, :high => 1, :very_high => 2}
  DEFAULT_NOTIFICATION = Growl.new("Growler seeks your attention.", :name => "Growler Notification")
  NOTIFICATION_CENTER = OSX::NSDistributedNotificationCenter.defaultCenter
  FROZEN_ATTRIBUTES_PATH = File.join(HERE, "resources", "growl_attributes.yaml")
  # The names of the different (instance) attributes on the Growl class.
  CATTR_NAMES = [:name, :path, :host, :icon, :all_notifications, :default_notifications, :registered]
  # The names of the different attributes on Growl instances.
  ATTR_NAMES = [:message, :title, :sticky, :icon, :icon_path, :priority, :app_icon, :image]
  DEFAULT_ATTRIBUTES = {:name => "Growler",
                        :path => "/usr/local/bin/growlnotify",
                        :host => "localhost",
                        :icon => OSX::NSData.data,
                        :all_notifications => [DEFAULT_NOTIFICATION],
                        :default_notifications => [DEFAULT_NOTIFICATION],
                        :registered => false}
  @frozen = File.exist?(FROZEN_ATTRIBUTES_PATH)

  def self.post(notification_name, overrides = {})
    
  end

  def self.frozen?
    @frozen
  end

  def self.load_attributes_from_default_or_frozen_file
    if frozen?
      return File.open(FROZEN_ATTRIBUTES_PATH) {|file| YAML.load(file)}
    else
      return DEFAULT_ATTRIBUTES
    end
  end

  GROWL_ATTRIBUTES = load_attributes_from_default_or_frozen_file
  
  def self.registered?
    @registered
  end

  def self.register!
    cocoa_registration_data = {"ApplicationName" => @name,
                               "AllNotifications" => OSX::NSArray.arrayWithArray(@all_notifications.collect(&:name)),
                               "DefaultNotifications" => OSX::NSArray.arrayWithArray(@default_notifications.collect(&:name)),
                               "ApplicationIcon" => @icon}
    attrs = OSX::NSDictionary.dictionaryWithDictionary(cocoa_registration_data)
    name = "GrowlApplicationRegistrationNotification"
    NOTIFICATION_CENTER.postNotificationName_object_userInfo_deliverImmediately(name, nil, attrs, true)
    @registered = true
  end
  
  # Freezes the changes you made to the attributes on the Growl class.
  # Writes them to a YAML file within the directory structure.
  def self.freeze_attributes!
    attrs = {:name => @name,
             :path => @path,
             :host => @host,
             :icon => @icon,
             :all_notifications => @all_notifications,
             :default_notifications => @default_notifications,
             :registered => @registered}
    File.open(FROZEN_ATTRIBUTES_PATH, File::WRONLY|File::TRUNC|File::CREAT, 0777) { |file| file.puts(attrs.to_yaml) }
    @frozen = true
  end
  
  # Returns false if successful. Something to watch out for.
  def self.unfreeze_attributes!
    FileUtils.rm(FROZEN_ATTRIBUTES_PATH)
    @frozen = false
  end
  
  def self.all_notifications
    @all_notifications
  end
  
  def self.default_notifications
    @default_notifications
  end
  
  def self.add_notification(name)
    unless @all_notifications.include?(name)
      @all_notifications << name
      @default_notifications << name
    end
  end
  
  def self.remove_notification(name)
    @all_notifications.delete(name)
  end
  
  def self.enable_notification(name)
    if @all_notifications.include?(name) && !@default_notifications.include?(name)
      @default_notifications << name
    end
  end
  
  def self.disable_notification(name)
    @enabled_notifications_list.delete(name)
  end
  
  def self.set_defaults!(defaults = {})
    CATTR_NAMES.each do |key|
      self[key] = defaults[key] if defaults.has_key?(key)
    end
    check_for_missing_attrs
  end
  
  def self.restore_defaults!
    set_defaults!(DEFAULT_ATTRIBUTES)
  end
  
  def self.check_for_missing_attrs
    missing_attrs = CATTR_NAMES.collect {|name| name if self.instance_variable_get(:"@#{name}").nil?}.compact
    if missing_attrs.empty?
      return true
    else
      raise GrowlerInitilizationError, "Missing required attributes! (#{missing_attrs.join(", ")})"
    end    
  end
  
  # The show-stopper. Sets the Growl class defaults either from a YAML file or from the provided
  # hardcoded defaults. Allow some semblance of persistence until Maglev becomes a reality, I guess...
  self.set_defaults!(GROWL_ATTRIBUTES)

  protected
  
  def self.app_name_for(name)
    name =~ /.*\.app$/ ? name : name + ".app"    
  end
  
  def self.priority_for(sym)
    Growl::PRIORITIES[sym] || 0
  end
  
  # Intelligently transforms simple inputs for :app_icon, :image, and :priority
  # into what growlnotify expects.
  def transmogrify(attribute, value)
    return case attribute
    when :app_icon
      Growl.app_name_for(value)
    when :icon_path
      value ? File.expand_path(value) : nil
    when :image
      value ? File.expand_path(value) : nil
    when :priority
      value.is_a?(Numeric) ? value : Growl.priority_for(value)
    else
      value
    end
  end
  
  def build_message_string      
    str = []
    str << "-s"                   if sticky?
    str << "-n '#{Growl[:name]}'" if Growl[:name]
    str << "-d '#{@name}'"        if @name
    str << "-m '#{@message}'"
    str << "-i '#{@icon}'"        if @icon
    str << "-I '#{@icon_path}'"   if @icon_path
    str << "--image '#{@image}'"  if @image
    str << "-a '#{@app_icon}'"    if @app_icon
    str << "-p #{@priority}"      if @priority
    str << "-H #{@host}"          if @host
    str << "-t '#{@title}'"       if @title
    str.join(" ")
  end
 
  def cli_only_attrs?
    @icon or @icon_path or @image or @app_icon
  end
  
  def post_using_cli
    %x[#{Growl[:path]} #{self.build_message_string}]
  end
  
  def post_using_cocoa(overrides = {})
    cocoa_notification_data = {"NotificationName" => (@name || Growl::DEFAULT_NOTIFICATION[:name]),
                               "ApplicationName" => Growl[:name],
                               "NotificationTitle" => (@title || ""),
                               "NotificationDescription" => @message,
                               "NotificationIcon" => (@icon || Growl[:icon]),
                               "NotificationSticky" => OSX::NSNumber.numberWithBool(@sticky),
                               "NotificationPriority" => OSX::NSNumber.numberWithInt(@priority)}
    attrs = OSX::NSDictionary.dictionaryWithDictionary(cocoa_notification_data.merge(overrides))
    NOTIFICATION_CENTER.postNotificationName_object_userInfo_deliverImmediately("GrowlNotification", nil, attrs, true)
  end
  
  def stick_using_cli
    sticky? ? post_using_cli : %x[#{Growl[:path]} -s #{self.build_message_string}]
  end
  
  def stick_using_cocoa(overrides = {})
    post_using_cocoa(overrides.merge({"NotificationSticky" => OSX::NSNumber.numberWithBool(true)}))
  end
end