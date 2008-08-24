module Growl
  class Notification
    include Growl::PriorityExtractor
    include Growl::Network::Notification
    
    WR_ATTRIBUTES = [:app_name, :title, :sticky, :host, :password]
    RO_ATTRIBUTES = [:name, :message, :priority]
    ATTRIBUTES = WR_ATTRIBUTES + RO_ATTRIBUTES
    WR_ATTRIBUTES.each { |a| attr_accessor  a }
    RO_ATTRIBUTES.each { |a| attr_reader    a }
    attr_reader :parent
    alias_method :sticky?, :sticky
   
    # Initializes a new Growl::Notification instance. Pass a Growl::Application object to act as
    # this notification's "parent" and/or a hash of attributes for this notifications. Will set
    # the following defaults if you don't specify them:
    # * :app_name - name of the application passed as the parent, or "growlnotify"
    # * :name - "Command-Line Growl Notification"
    # * :image - icon of parent application, unless :image_path, :icon_path, :file_type, or :app_icon was also passed
    # * :sticky - false
    # * :message - ""
    # * :title - ""
    def initialize(*args)
      attributes = args.last.is_a?(Hash) ? args.pop : {}
      @parent = args[0]
      if @parent && @parent.is_a?(Growl::Application)
        @app_name = @parent.name
        @host = @parent.host
        @password = @parent.password
      else
        @app_name = nil
      end
      @name = attributes[:name]
      @title = attributes[:title] || @name
      @sticky = attributes[:sticky] || false
      @priority = get_priority_for(attributes[:priority] || 0)
      @message = DynamicString.new(attributes[:message] || "")
    end

    # The name of the Growl::Application that this notification belongs to.
    def application_name
      @parent.name if @parent
    end
    
    # Catch-all attribute reader. Used internally to mock exposing notification attributes as a
    # Hash, which is clean and convenient syntax; can be used publically if needed.
    #
    # Note that the setter analogue, []=, is protected and its use publically is not advised since
    # it doesn't perform data transformations like the traditional setter methods (attribute=) do.
    def [](attribute)
      self.instance_variable_get("@#{attribute}")
    end
    
    # Returns a hash of the attributes of the message.
    def get_attributes
      attributes = {}
      ATTRIBUTES.each do |attribute|
        attributes[attribute] = self[attribute]
      end
      return attributes
    end
    
    # Setter for the name attribute. Will set this notification's title to the same as its name if the
    # title is not already set. This is advocated by the Growl documentation, since it encourages helpful,
    # descriptive names of notifications.
    def name=(str)
      @name = str
      @title ||= DynamicString.new(@name)
      @name
    end
    
    # Setter for the message attribute. Creates a new DynamicString instance with the given base string
    # and capture pattern. For non-dynamic messages, you need only worry about passing a string to this method.
    # Otherwise, read up about DynamicStrings to see how to make dynamic message templates.
    def message=(*args)
      @message = DynamicString.new(*args)
    end
    
    # Setter for the title. Creates a new DynamicString instance with the given base string and capture
    # pattern. See DynamicString for details on how to use them.
    def title=(*args)
      @title = DynamicString.new(*args)
    end
    
    # Accepts either a priority name as a symbol (:very_low, :moderate, :normal, :high, or
    # :emergency) or an integer bewteen -2 and 2 to set this notification's priorty. Keep in mind
    # that the priority of a notification doesn't automatically mean anything; it just allows the
    # end user to customize display settings for notifications with various priorities.
    def priority=(value)
      @priority = get_priority_for(value)
    end
    
    # Posts the message.
    # A hash of overrides can be passed to change the behavior of the output without changing the
    # object's attributes.
    #
    # While you can theoretically override the message's app_name and name, doing so without first
    # having registered an application with that app_name having a (default) message of that name
    # will result in no message getting posted. This could possibly be useful to make one message
    # masquerade as if sent by a different program, should you ever want to.
    #
    # Other keys passed to overrides will be sent to the message and title to be dynamically rendered.
    # See DynamicString for details about this. If both the title and message have a variable of the
    # same name, passing that key will get interpolated into both strings. For (a bogus) example:
    #   msg = Growl::Notification.new(:name => "Files Converted")
    #   msg.title = "{number} Files Converted"
    #   msg.message = "{number} files were successfully converted in {dir}."
    #   ... (application registration and stuff) ...
    #   msg.post(:number => 2, :dir => File.dirname(__FILE__))
    def post(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      tmp_host = args[0] || options[:to] || options[:host] || @host
      tmp_password = args[1] || options[:password] || @password
      @socket = UDPSocket.open
      @socket.connect tmp_host, Growl::UDP_PORT
      send_data! build_notification_packet(tmp_password, options)
    end
    alias_method :notify, :post

    # Posts the message forcing :sticky => true.
    def pin(*args)
      args << args.last.is_a?(Hash) ? args.pop.merge({:sticky => true}) : {:sticky => true}
      post(*args)
    end
    alias_method :stick, :pin
    
    private
    
    # Catch-all attribute setter. Used internally; use the other setters to set attributes, since
    # those will transform inputs into the correct types.
    def []=(attribute, value)
      self.instance_variable_set("@#{attribute}", value)
    end    
  end
end