class Hash

  # Deletes each key included in the arguments. Useful for masking the keys of a hash.
  def strip_keys(*keys_to_strip)
    delete_if {|key, value| keys_to_strip.include?(key)}
  end
  
  # Strips keys in place.
  def strip_keys!(*keys_to_strip)
    replace(strip_keys(*keys_to_strip))
  end
  
  def debug #:nodoc:
    each do |key, value|
      puts ":#{key} => #{value}"
    end
  end

end