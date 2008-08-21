module Growl
  module Version #:nodoc:#
    MAJOR = 0
    MINOR = 2
    TINY  = 0
    
    STRING = [MAJOR, MINOR, TINY].join(".")
  end
  
  def self.version
    Growl::Version::STRING
  end
end