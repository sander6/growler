require 'osx/cocoa'

module Growl
  module Transmogrifier
  WORKSPACE = OSX::NSWorkspace.sharedWorkspace

  class << self
    include OSX
    
    def simple_app_icon_for(name)
      name =~ /.*\.app$/ ? name : name + ".app"
    end
    
    def app_icon_for(name_or_path, hint = nil)
      klass = name_or_path.class
      case klass
      when String
        path = File.expand_path(name_or_path)
        # If File.exist?, assumes that you passed a path to an image to use.
        if File.exist?(File.expand_path(path))
          img = NSImage.new.initWithContentsOfFile(NSString.stringWithString(path))
          # If the file at the path is not an image file, the above function will return nil.
          # If that's the case, iconForFile will take the icon of the file specified by the
          # path (instead of the contents of the file).
          img ||= WORKSPACE.iconForFile(NSString.stringWithString(path))
        else
          app_path = WORKSPACE.fullPathForApplication(name_or_path)
          if app_path
            # If an application name was passed, will get that application's icon
            img = WORKSPACE.iconForFile(NSString.stringWithString(app_path))
          else
            # Else, assumes argument was a file type and finds the system icon for that
            # file type.
            img = WORKSPACE.iconForFileType(NSString.stringWithString(name_or_path))
          end
        end
      when NSImage
        # If you somehow come across an NSImage object, this message will accept that.
        img = name_or_path
      else
        return nil
      end
      # Returns an NSData object, which is what Growl is expecting.
      return img.TIFFRepresentation if img.respond_to?(:TIFFRepresentation)
    end
    
    # Intelligently transforms simple inputs for :app_icon, :image, and :priority
    # into what growlnotify expects.
    def transmogrify(attribute, value)
      return case attribute
      when :app_icon
        self.app_name_for(value)
      when :icon_path
        value ? File.expand_path(value) : nil
      when :image
        value ? File.expand_path(value) : nil
      when :priority
        value.is_a?(Numeric) ? value : self.priority_for(value)
      else
        value
      end
    end
  
    # Massages data to fit expected datatypes.
    def transmogrify(attribute, value)
      return case attribute
      when :icon
        transmogrify_icon(value)
      when :priority
        transmogrify_priority(value)
      else
        value
      end
    end
    
    # Currently just returns blank OSX::NSData. This makes Growl use the system default application icon.
    # Will eventually try to take an application name or image path as input and use that.
    def transmogrify_icon(icon)
      OSX::NSData.data
    end
    
    # Converts priority symbol names to their integer counterparts.
    # Rewards idiots who pass invalid priority arguments by setting a sensible default instead of raising
    # an exception.
    def transmogrify_priority(value)
      if value.kind_of?(Symbol)
        return Growl::PRIORITIES[value] || 0
      elsif value.kind_of?(Integer) && (-2..2).include?(value)
        return value
      else
        return 0
      end
    end
    
    
  end
end