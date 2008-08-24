# A DynamicString holds a base string containing placeholder variables to be interpreted
# when the message is rendered. For example:
#   msg = DynamicString.new("I'm feeling rather {emotion} today.")
#   msg.render :emotion => "happy" # => "I'm feeling rather happy today."
# Each placeholder variable name must be a valid Ruby variable name (i.e. only letter, numbers
# and underscores) but you can pad the name with as much whitespace as you'd like. That is,
# "{variable}" is just as good as "{ variable }". Everything between the curly braces will be
# replaced with the value for the passed key.
class DynamicString < String

  @@default_capture_pattern = "{...}"

  # Getter for the default starting capture pattern (default is "{...}").
  def self.default_capture_pattern
    @@default_capture_pattern
  end

  # Setter for the default starting capture pattern.
  def self.default_capture_pattern=(pattern)
    @@default_capture_pattern = pattern
  end

  attr_reader :capture_start, :capture_end, :captures, :defaults

  # Creates a new Message instance given a base string with placeholders demarcated by a start
  # and end pattern. The default pattern is "{...}". You can define this to be whatever you like
  # but you must add the three dots in the middle (padded by however much whitespace you'd like)
  # so that the pattern parser knows where to start and stop. Examples of valid capture patterns
  # include "[...]", "<% ... %>", "^...$", and " :: ... :: ". Although valid, it's generally not
  # a good idea to use letters or numbers in the capture pattern (that is, "BEGIN...END" might
  # cause some weirdness to arise.)
  #
  # You can pass a hash of default values for each placeholder when you're initializing the
  # dynamic string. Pass placeholder names as Symbols.
  #
  # Some examples:
  #   msg = DynamicString.new("The time is {time}.", :time => Time.now)
  #   msg = DynamicString.new("The date is currently [date].", "[...]")
  #   msg = DynamicString.new("Growler is totally :adjective:.", ":...:", :adjective => "awesome")
  def initialize(*args)
    @defaults = args.last.is_a?(Hash) ? args.pop : {}
    base_str = args[0] || ""
    pattern = args[1] || @@default_capture_pattern
    super(base_str)
    @capture_start, @capture_end = parse_capture_pattern(pattern)
    @captures = capture_variable_names
  end
  
  def capture_pattern=(pattern)
    @capture_start, @capture_end = parse_capture_pattern(pattern)
    @captures = capture_variable_names
    return self
  end
  
  # Returns the number of variables in this message.
  def arity
    @captures.size
  end

  # Interpolates the base string given a hash of variable names and values.
  def render(vars = {})
    vars = @defaults.merge vars
    rendered_string = dup
    @captures.each do |var|
      rendered_string.gsub!(capture_expression(var), vars[var].to_s) if vars.has_key?(var) 
    end
    rendered_string
  end

  private

  def capture_variable_names
    scan(capture_expression("([\\w\\d_]+)")).flatten.collect {|var| var.to_sym}
  end

  def capture_expression(middle_bit = ".*")
    %r{#{escape(@capture_start)}\s*#{middle_bit}\s*#{escape(@capture_end)}}
  end

  def escape(str)
    str.gsub(/(\\|\/|\||\*|\$|\^|\?|\{|\}|\.|\(|\))/) {|s| "\\#{$&}"}
  end
  
  def parse_capture_pattern(pattern)
    pattern = @@default_capture_pattern unless pattern =~ /\.\.\./
    patterns = pattern.scan(/(\S+)\s*\.\.\.\s*(\S+)/).flatten
    return *patterns
  end
  
end