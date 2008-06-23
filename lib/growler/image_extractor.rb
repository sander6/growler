require 'objc'

module Growl
  
  # The ImageExtractor allows images (for notification icons) to be references simply
  # by manipulating data in clever ways.
  module ImageExtractor
    
    # ImageExtractor::ObjectiveC helps take the hash of attributes passed when creating
    # a Growl::Application or Growl::Notification and locating the proper image as an
    # ObjC::NSImage object. This allows one to say something like
    #   Growl::Notification.new(:app_icon => "Mail")
    # and be conifdent that ImageExtractor will go and do the right thing; that is,
    # find the application icon for Mail.app and use it as that Notification's icon.
    module ObjectiveC
      
      # This method is automatically called on the attributes hash passed when calling
      # new or set_attributes! on Application or Notification objects. It looks for the
      # following keys in order:
      #   - :image - an ObjC::NSImage object of the icon you want
      #   - :image_path - a path to an image file you want to use as the icon
      #   - :icon_path - a path to any file whose icon you want to use
      #   - :file_type_icon - a file-type or extension whose default icon you want to use
      #   - :app_icon - the name of an application whose file icon you want to use
      # (paths will be expanded using File.expand_path)
      #
      # The first of these keys which does not return a nil object will be used for the
      # Notification's icon, or the default icon for the Application.
      #
      # This method returns a ObjC::NSImage object.
      def extract_image_from(attributes)
        img = nil
        if attributes.has_key?(:image) && attributes[:image].is_a?(ObjC::NSImage)
          img = attributes[:image]
        elsif (attributes.has_key?(:image_path) && !img)
          img = image_from_image_path(attributes[:image_path])
        elsif (attributes.has_key?(:icon_path) && !img)
          img = image_from_icon_path(attributes[:icon_path])
        elsif (attributes.has_key?(:file_type_icon) && !img)
          img = image_from_file_type_icon(attributes[:file_type_icon])
        elsif (attributes.has_key?(:app_icon) && !img)
          img = image_from_app_icon(attributes[:app_icon])
        end
        return img
      end

      # Takes the path supplied and returns an ObjC::NSImage object initialized with
      # the contents of the image at that path. Returns nil if the file at the path
      # is not a valid image.
      def image_from_image_path(path)
        ns_string = ObjC::NSString.stringWithString_(File.expand_path(path))
        ObjC::NSImage.alloc.initWithContentsOfFile_(ns_string)
      end

      # Takes the path supplied and returns an ObjC::NSImage object of that file's
      # icon. Note that even if the file the path points to is an image file, this
      # will load that image file's icon (e.g. the default .jpg icon) and not the
      # contents of the image.
      def image_from_icon_path(path)
        ns_string = ObjC::NSString.stringWithString_(File.expand_path(path))
        ObjC::NSWorkspace.sharedWorkspace.iconForFile_(ns_string)
      end

      # Takes a file type extention (such as "rb" or "pdf") and returns an ObjC::NSImage
      # object of that file type's default system icon.
      def image_from_file_type_icon(ext)
        ns_string = ObjC::NSString.stringWithString_(ext)
        ObjC::NSWorkspace.sharedWorkspace.iconForFileType_(ns_string)
      end

      # Takes the name of an application (such as "Safari" or "TextMate") and returns
      # an ObjC::NSImage object of that application's icon.
      def image_from_app_icon(name)
        ns_string = ObjC::NSString.stringWithString_(name)
        app_path = ObjC::NSWorkspace.sharedWorkspace.fullPathForApplication_(ns_string)
        ObjC::NSWorkspace.sharedWorkspace.iconForFile_(app_path)
      end
    end
    
    # ImageExtractor::Simple helps take the hash of attributes passed to the Growl module
    # when calling set_defaults! or post and make sure it is what growlnotify is expecting.
    module Simple
      
      # This method gets called on the hash passed to the Growl module when calling
      # set_defaults!, post, or pin. It looks for the following key in order:
      #   - :image - a path to an image file to use as the notification's icon
      #   - :icon_path - a path to a file whose icon you want to use as the notification's icon
      #   - :file_type_icon - a file type extension whose icon you want to use
      #   - :app_icon - the name of an application whose icon you want to use
      # (paths will be expanded using File.expand_path)
      #
      # The first of these keys that returns a non-nil value when searching for the image
      # will determine how the icon gets set. Therefore, passing both :image and :app_icon,
      # for example, will result in :image being used.
      #
      # If all the arguments are invalid (e.g. there's no file at the path specified), this
      # method returns nil and the notification will simply have no icon.
      def extract_image_from(attributes)
        img = nil
        if attributes.has_key?(:image)
          img = image_from_image_path(attributes[:image_path])
        elsif (attributes.has_key?(:icon_path) && !img)
          img = image_from_icon_path(attributes[:icon_path])
        elsif (attributes.has_key?(:file_type_icon) && !img)
          img = image_from_file_type_icon(attributes[:file_type_icon])
        elsif (attributes.has_key?(:app_icon) && !img)
          img = image_from_app_icon(attributes[:app_icon])
        end
        return img
      end
      
      # Takes a path to a image file that you want to use as the notification's icon.
      # Returns nil if the file doesn't exist.
      def image_from_image_path(path)
        File.expand_path(path) if File.exist?(File.expand_path(path))
      end
  
      # Takes a path to any file whose icon you want to use for the notification's icon.
      # Note that even if the file this path points to is an image file, will use that
      # file's icon (e.g. the default .jpg icon) and not the file's contents.
      # Returns nil if the file doesn't exist.
      def image_from_icon_path(path)
        File.expand_path(path) if File.exist?(File.expand_path(path))
      end

      # Takes a file type extension (such as "rb" or "txt") whose default system icon you
      # want to use for the notification's icon.
      def image_from_file_type_icon(ext)
        ext
      end

      # Takes the name of an application (such as "Safari" or "TextMate") whose application
      # icon you want to use for the notification's icon.
      def image_from_app_icon(name)
        name =~ /.*\.app$/ ? name : (name + "app") if name
      end
    end
  end
end