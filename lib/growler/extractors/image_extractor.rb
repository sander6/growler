require 'osx/cocoa'

module Growl
  
  # ImageExtractor helps take the hash of attributes passed when creating
  # a Growl::Application or Growl::Notification and locating the proper image as an
  # OSX::NSImage object. This allows one to say something like
  #   Growl::Notification.new(:app_icon => "Mail")
  # and be confident that ImageExtractor will go and do the right thing; that is,
  # find the application icon for Mail.app and use it as that Notification's icon.
  module ImageExtractor
    
    # This method is automatically called on the attributes hash passed when calling
    # new or set_attributes! on Application or Notification objects. It looks for the
    # following keys in order:
    # - :image - an OSX::NSImage object of the icon you want
    # - :image_path - a path to an image file you want to use as the icon
    # - :icon_path - a path to any file whose icon you want to use
    # - :file_type - a file-type or extension whose default icon you want to use
    # - :app_icon - the name of an application whose file icon you want to use
    # (paths will be expanded using File.expand_path)
    #
    # The first of these keys which does not return a nil object will be used for the
    # Notification's icon, or the default icon for the Application.
    #
    # This method returns a OSX::NSImage object.
    def extract_image_from(attributes)
      img = nil
      if attributes.has_key?(:image) && attributes[:image].is_a?(OSX::NSImage)
        img = attributes[:image]
      elsif (attributes.has_key?(:image_path) && !img)
        img = image_from_image_path(attributes[:image_path])
      elsif (attributes.has_key?(:icon_path) && !img)
        img = image_from_icon_path(attributes[:icon_path])
      elsif (attributes.has_key?(:file_type) && !img)
        img = image_from_file_type(attributes[:file_type_icon])
      elsif (attributes.has_key?(:app_icon) && !img)
        img = image_from_app_icon(attributes[:app_icon])
      end
      return img
    end
          
    # Takes the path supplied and returns an OSX::NSImage object initialized with
    # the contents of the image at that path. Returns nil if the file at the path
    # is not a valid image.
    def image_from_image_path(path)
      OSX::NSImage.alloc.initWithContentsOfFile_(path)
    end

    # Takes the path supplied and returns an OSX::NSImage object of that file's
    # icon. Note that even if the file the path points to is an image file, this
    # will load that image file's icon (e.g. the default .jpg icon) and not the
    # contents of the image.
    def image_from_icon_path(path)
      OSX::NSWorkspace.sharedWorkspace.iconForFile_(File.expand_path(path))
    end

    # Takes a file type extention (such as "rb" or "pdf") and returns an OSX::NSImage
    # object of that file type's default system icon.
    def image_from_file_type(ext)
      OSX::NSWorkspace.sharedWorkspace.iconForFileType_(ext)
    end

    # Takes the name of an application (such as "Safari" or "TextMate") and returns
    # an OSX::NSImage object of that application's icon.
    def image_from_app_icon(name)
      app_path = OSX::NSWorkspace.sharedWorkspace.fullPathForApplication_(name)
      OSX::NSWorkspace.sharedWorkspace.iconForFile_(app_path)
    end
  end
end