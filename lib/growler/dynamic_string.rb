# A DynamicString holds a base string containing placeholder variables to be interpreted
# when the message is rendered. For example:
#   msg = DynamicString.new("I'm feeling rather {emotion} today.")
#   msg.render :emotion => "happy" # => "I'm feeling rather happy today."
# Each placeholder variable name must be a valid Ruby variable name (i.e. only letter, numbers
# and underscores) but you can pad the name with as much whitespace as you'd like. That is,
# "{variable}" is just as good as "{ variable }". Everything between the curly braces will be
# replaced with the value for the passed key.
#
# DynamicStrings do not depend on any other part of Growler, so feel free to use them wherever
# you'd like, provided that you can't think of a much better solution yourself.

class DynamicString < String

  @@default_capture_pattern = "{...}"

  # Getter for the default variable capture pattern (default is "{...}").
  def self.default_capture_pattern
    @@default_capture_pattern
  end

  # Setter for the default variable capture pattern.
  def self.default_capture_pattern=(pattern)
    @@default_capture_pattern = pattern
  end

  attr_reader :capture_start, :capture_end, :captures, :defaults

  # Creates a new DynamicString instance given a base string with placeholders demarcated by a start
  # and end pattern. The default pattern is "{...}". You can define this to be whatever you like
  # but you must add the three dots in the middle (padded by however much whitespace you'd like)
  # so that the pattern parser knows where to start and stop. Examples of valid capture patterns
  # include "[...]", "<% ... %>", "^...$", and " :: ... :: ". Although valid, it's generally not
  # a good idea to use letters or numbers in the capture pattern (that is, "BEGIN...END" might
  # cause some weirdness to arise.).
  #
  # You can pass a hash of default values for each placeholder when you're initializing the
  # dynamic string. Pass placeholder names as Symbols.
  #
  # Some examples:
  #   msg = DynamicString.new("The time is {time}.", :time => Time.now)
  #   msg = DynamicString.new("The date is currently [date].", "[...]")
  #   msg = DynamicString.new("Growler is totally :adjective:.", ":...:", :adjective => "awesome")
  #
  # DynamicStrings set their own capture start and end patterns and set of captured
  # variables on a per-instance basis which is calculated only when initialized or when the
  # capture pattern is replaced using capture_pattern=. This means that setting the DynamicString
  # class variable for @@default_capture_pattern will not affect the patterns or variables
  # in DynamicStrings that have already been instantiated. They will render correctly. Future
  # DynamicStrings, though, will be looking for their variables to be enclosed in the new
  # pattern.
  #
  # Example:
  #   score = DynamicString.new("Your score is {score}", :score => 0)
  #   DynamicString.default_capture_pattern = "[...]"
  #   performance = DynamicString.new("You did [adverb].", :adverb => "abysmally")
  #
  #   score.capture_start # => "{"
  #   performance.capture_start # => "["
  #
  #   score.render # => "Your score is 0."
  #   performance.render # => "You did abysmally."
  def initialize(*args)
    @defaults = args.last.is_a?(Hash) ? args.pop : {}
    base_str = args[0] || ""
    pattern = args[1] || @@default_capture_pattern
    super(base_str)
    @capture_start, @capture_end = parse_capture_pattern(pattern)
    @captures = capture_variable_names
  end
  
  # Redefines the capture start and end pattern as well as the captures variables given
  # a new capture pattern. In practice, this is not the most useful thing to do, as you
  # might find out if you start working with DynamicStrings a lot.
  def capture_pattern=(pattern)
    @capture_start, @capture_end = parse_capture_pattern(pattern)
    @captures = capture_variable_names
    return self
  end
  
  # Returns the number of variables in this message.
  def arity
    @captures.size
  end

  # Interpolates the base string given a hash of variable names and values, which will be
  # merged with any defaults.
  #
  # A Strongbadian example:
  #   string = DynamicString.new("Your {body_part} is {adjective}.", :body_part => "face")
  #   string.captures # => [:body_part, :adjective]
  #   string.defaults # => {:body_part => "face"}
  #   string.render :adjective => "stupid" # => "Your face is stupid."
  #   string.render :body_part => "butt", :adjective => "stupid" # => "Your butt is stupid."
  def render(vars = {})
    vars = @defaults.merge vars
    rendered_string = dup
    @captures.each do |var|
      rendered_string.gsub!(capture_expression(var), vars[var].to_s) if vars.has_key?(var) 
    end
    rendered_string
  end

  private

  # Parses the string and collects the variable names into an Array.
  def capture_variable_names
    scan(capture_expression("([\\w\\d_]+)")).flatten.collect {|var| var.to_sym}
  end

  # Builds the Regexp to find things in the string based on the capture_start and
  # capture_end patterns. Generic enough for both variable extraction and interpolation.
  def capture_expression(middle_bit = ".*")
    %r{#{escape(@capture_start)}\s*#{middle_bit}\s*#{escape(@capture_end)}}
  end

  # Escapes all Regexpy symbols in a string.
  def escape(str)
    str.gsub(/(\\|\/|\||\*|\$|\^|\?|\{|\}|\.|\(|\))/) {|s| "\\#{$&}"}
  end
  
  # Takes a capture pattern, such as "<%...%>", and parses it into a starting and
  # ending pattern based on where the three dots are. Returns the class default if
  # the capture_pattern is invalid (i.e. it doesn't have three dots in it.)
  # For example:
  #   parse_capture_pattern("<%...%>") # => "<%", "%>"
  def parse_capture_pattern(pattern)
    pattern = @@default_capture_pattern unless pattern =~ /\.{3}/
    patterns = pattern.scan(/(\S+)\s*\.{3}\s*(\S+)/).flatten
    return *patterns
  end
  
end