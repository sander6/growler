class Module
  def mattr_reader(*attributes)
    attributes.each do |attribute|
      self.module_eval(<<-EOS, __FILE__, __LINE__)
        def self.#{attribute}
          @#{attribute}
        end
      EOS
    end
  end
  
  def mattr_writer(*attributes)
    attributes.each do |attribute|
      self.module_eval(<<-EOS, __FILE__, __LINE__)
        def self.#{attribute}=(value)
          @#{attribute} = value
        end
      EOS
    end
  end
  
  def mattr_accessor(*attributes)
    mattr_reader(*attributes)
    mattr_writer(*attributes)
  end
end