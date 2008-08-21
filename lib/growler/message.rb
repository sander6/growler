module Growl
  
  # A Growl::Message holds a base message string containing placeholder variables to be interpreted
  # when the message is rendered. For example:
  #   msg = Growl::Message.new("I'm feeling rather {emotion} today.")
  #   msg.render :emotion => "happy" # => "I'm feeling rather happy today."
  # Each placeholder variable name must be a valid Ruby variable name (i.e. only letter, numbers
  # and underscores) but you can pad the name with as much whitespace as you'd like. That is,
  # "{variable}" is just as good as "{ variable }". Everything between the curly braces will be
  # replaced with the value for the passed key.
  class Message
    CLOSING_PAIRS = {"{" => "}", "[" => "]", "(" => ")"}
    @@default_capture_start = "{"
    
    # Getter for the default starting capture pattern (default is "{").
    def self.default_capture_start
      @@default_capture_start
    end
    
    # Setter for the default starting capture pattern.
    def self.default_capture_start=(pattern)
      @@default_capture_start = pattern
    end
    
    attr_reader :base, :capture_start, :capture_end, :captures
    alias_method :variables, :captures
    
    # Creates a new Message instance given a base string with placeholders demarcated by a start
    # and end pattern. The default pattern is "{placeholder}". Given a left-bracket of some sort,
    # i.e. {, [, or (, the end pattern will default to the closing right-bracket, otherwise, the
    # start and end patterns will be the same.
    #
    # Some examples:
    #   msg = Growl::Message.new("The time is now {time}.")
    #   msg = Growl::Message.new("The date is currently [date].", "[")
    #   msg = Growl::Message.new("Growler is totally :adjective:.", ":")
    def initialize(base_string = "", capture_start_pattern = @@default_capture_start, capture_end_pattern = nil)
      @base = base_string || ""
      @capture_start = capture_start_pattern || @@default_capture_start
      if capture_end_pattern.nil?
        matched_pair = @capture_start.scan(/./).collect {|bit| CLOSING_PAIRS[bit]}.join
        @capture_end = matched_pair == "" ? @capture_start : matched_pair
      else
        @capture_end = capture_end_pattern
      end
      @captures = capture_variable_names
    end
    
    # Returns the number of variables in this message.
    def arity
      @captures.size
    end
    
    # Interpolates the base string given a hash of variable names and values.
    def render(vars = {})
      # unless vars.keys.all? {|key| @captures.include?(key)}
      #   unknown_keys = vars.keys - @captures
      #   raise Growl::MessageRenderingError, "Unknown argument#{"s" if unknown_keys.size != 1}: #{unknown_keys.join(", ")}"
      # end
      # unless vars.size == arity
      #   adv = (vars.size <=> arity) == 1 ? "many" : "few"
      #   raise Growl::MessageRenderingError, "The message you're trying to render was passed too #{adv} arguments."
      # end
      rendered_string = @base.dup
      @captures.each do |var|
        rendered_string.gsub!(capture_expression(var), vars[var]) if vars.has_key?(var) 
      end
      rendered_string
    end
    
    private
    
    def capture_variable_names
      @base.scan(capture_expression("([\\w\\d_]+)")).flatten.collect {|var| var.to_sym}
    end
    
    def capture_expression(middle_bit = ".*")
      %r{#{escape(@capture_start)}\s*#{middle_bit}\s*#{escape(@capture_end)}}
    end

    def escape(str)
      str.gsub(/(\\|\/|\||\*|\$|\^|\?|\{|\}|\.|\(|\))/) {|s| "\\#{$&}"}
    end

  end
  
  # class MessageRenderingError < StandardError
  # end
end