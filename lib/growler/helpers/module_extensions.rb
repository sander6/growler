class Module
  
  # Akin to attr_reader, creates getter methods for class variables on a Module.
  def mattr_reader(*attributes)
    attributes.each do |attribute|
      self.module_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{attribute}
          @@#{attribute} = nil
        end
      
        def self.#{attribute}
          @@#{attribute}
        end
      EOS
    end
  end

  # Akin to attr_writer, creates setter methods for class variables on a Module.
  def mattr_writer(*attributes)
    attributes.each do |attribute|
      self.module_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{attribute}
          @@#{attribute} = nil
        end
      
        def self.#{attribute}=(value)
          @@#{attribute} = value
        end
      EOS
    end
  end
  
  # Akin to attr_accessor, creates getter and setter methods for class variables on
  # a Module.
  def mattr_accessor(*attributes)
    mattr_reader(*attributes)
    mattr_writer(*attributes)
  end
end