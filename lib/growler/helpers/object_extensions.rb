module Growl
  module ObjectExtensions
    
    # Like a reverse Symbol#to_proc: instead of sending the same method to each
    # object in an array, sends each method in an array to an object.
    # Example:
    # [:upcase, :downcase, :reverse].collect(&"cRaZineSs!")
    # => ["CRAZINESS!", "craziness!", "!sSeniZaRc"]
    #
    # For some weird reason I keep finding myself using this idiom, so I figured
    # I might as well capture it in a utility method.
    def to_proc
      Proc.new { |method, *args| self.send(method, *args) }
    end
    
    # Catch-all way to set attributes on a object with a hash.
    def set_attributes!(attrs = {})
      attrs.each do |key, value|
        self.send :"#{key}=", value if self.respond_to?(:"#{key}=")
      end
      return self
    end
    
    # Borrowed from Rails' method of the same name. Used internally.
    def returning(value)
      yield value
      value
    end
    
  end
end

class Object
  include Growl::ObjectExtensions
end