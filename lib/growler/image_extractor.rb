require 'objc'

module Growl
  class ImageExtractor
    include ObjC

    class << self
               
      def extract_image_from(attributes)
        img = nil
        if attributes.has_key?(:image) && attributes[:image].is_a?(NSImage)
          img = attributes[:image]
        elsif attributes.has_key?(:image_path)
          img = image_from_image_path(attributes[:image_path])
        elsif attributes.has_key?(:icon_path)
          img = image_from_icon_path(attributes[:icon_path])
        elsif attributes.has_key?(:file_type_icon)
          img = image_from_file_type_icon(attributes[:file_type_icon])
        elsif attributes.has_key?(:app_name)
          img = image_from_app_name(attributes[:app_name])
        end
        return img
      end
    
      def image_from_image_path(path)
        ns_string = NSString.stringWithString_(File.expand_path(path))
        NSImage.alloc.initWithContentsOfFile_(ns_string)
      end
    
      def image_from_icon_path(path)
        ns_string = NSString.stringWithString_(File.expand_path(path))
        NSWorkspace.sharedWorkspace.iconForFile_(ns_string)
      end
    
      def image_from_file_type_icon(ext)
        ns_string = NSString.stringWithString_(ext)
        NSWorkspace.sharedWorkspace.iconForFileType_(ns_string)
      end
    
      def image_from_app_name(name)
        ns_string = NSString.stringWithString_(name)
        app_path = NSWorkspace.sharedWorkspace.fullPathForApplication_(ns_string)
        NSWorkspace.sharedWorkspace.iconForFile_(app_path)
      end
            
    end
  end
end