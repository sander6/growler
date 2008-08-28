module Growl
  module Version #:nodoc:#
    MAJOR = 0
    MINOR = 3
    TINY  = 0
    
    STRING = [MAJOR, MINOR, TINY].join(".")
  end
  
  # Returns the current version.
  def self.version
    Growl::Version::STRING
  end
end