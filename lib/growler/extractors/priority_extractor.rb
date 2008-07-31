module Growl
  
  # The PriorityExtractor assists in converting priority symbol names to numerical values.
  module PriorityExtractor
    PRIORITIES = {:very_low => -2, :moderate => -1, :normal => 0, :high => 1, :emergency => 2}
    
    # Converts priority symbol names to their integer counterparts. Invalid arguments (i.e. bogus
    # priority symbol names, integer priority values out of the (-2..2) range, or any other object)
    # will return the default value of 0 (:normal).
    def get_priority_for(value)
      if value.kind_of?(Symbol)
        return PRIORITIES[value] || 0
      elsif value.kind_of?(Integer) && (-2..2).include?(value)
        return value
      else
        return 0
      end
    end 
  end
end