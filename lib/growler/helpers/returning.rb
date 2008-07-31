module Growl
  module Returning
    
    # Borrowed from Rails' method of the same name. Used internally.
    def returning(value)
      yield value
      value
    end
    
  end
end