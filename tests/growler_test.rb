require 'test_helper.rb'
require '../lib/growler.rb'
require 'test/unit'

class GrowlerTest < Test::Unit::TestCase
  include TestHelper
  
  def setup
    @growl = Growl.new
  end

  # Testing that Growl.[] works.
  def test_should_get_class_defaults
    assert_equal Growl.instance_variable_get(:@host), Growl[:host]
  end
  
  # Testing that Growl.[]= works.
  def test_should_set_class_defaults
    assert_changes Growl[:host] do
      Growl[:host] = "some.other.host"
      Growl[:host]
    end
  end
  
  def test_should_have_all_and_default_notifications_attr_readers
    assert Growl.respond_to?(:all_notifications)
    assert Growl.respond_to?(:default_notifications)
  end
    
  # Testing that new Growls inherit the default class attributes.
  def test_should_inherit_default_class_host
    assert_equal Growl[:host], @growl[:host]
  end
  
  def test_should_massage_app_icon
    @growl[:app_icon] = "Some App"
    assert_equal "Some App.app", @growl[:app_icon]
  end
  
  def test_should_massage_icon_path
    @growl[:icon_path] = "~/Desktop/some_folder.jpg"
    assert_equal File.expand_path("~/Desktop/some_folder.jpg"), @growl[:icon_path]
  end
  
  def test_should_massage_image
    @growl[:image] = "~/Desktop/some_image.jpg"
    assert_equal File.expand_path("~/Desktop/some_image.jpg"), @growl[:image]
  end
  
  def test_should_massage_priority
    @growl[:priority] = :very_high
    assert_equal 2, @growl[:priority]
  end
  
  def test_should_set_attributes_with_massaging_on_initialize
    @growl = Growl.new("test message", :title => "test title", :sticky => true, :app_icon => "Some App", :priority => :low)
    assert_equal  "test message",   @growl[:message]
    assert_equal  "test title",     @growl[:title]
    assert        @growl[:sticky]
    assert_equal  "Some App.app",   @growl[:app_icon]
    assert_equal  -1,               @growl[:priority]
  end
  
  # Testing that @growl.[] works
  def test_should_get_instance_attributes
    assert_equal @growl.instance_variable_get(:@msg), @growl[:msg]
  end
  
  # Testing that @growl.[]= works.
  def test_should_set_instance_attributes
    assert_changes @growl[:message] do
      @growl[:message] = "changed to something else."
      @growl[:message]
    end
  end
  
  def test_should_mass_assign_attributes
    attrs = {:message => "test message", :title => "test title", :sticky => true, :app_icon => "Some App", :priority => :low}
    @growl.set_attributes(attrs)
    assert_equal  "test message",   @growl[:message]
    assert_equal  "test title",     @growl[:title]
    assert        @growl[:sticky]
    assert_equal  "Some App.app",   @growl[:app_icon]
    assert_equal  -1,               @growl[:priority]    
  end
  
  # You'll have to check for yourself whether these messages actually show up or not.
  # def test_should_post_message_using_command_line_interface
  #   @growl.title("Command-Line Test Message").message("If you can see this, the test passes!").send :post_using_cli
  # end

  # def test_should_stick_message_using_command_line_interface
  #   @growl.title("Command-Line Sticky Message").message("If this remains after the others have faded, the test passes!").send :stick_using_cli
  # end

  def test_should_post_message
    @growl.title("Test Message").message("If you can see this, the test passes!").post
  end
  
  def test_should_pin_message
    @growl.title("Sticky Message").message("If this remains after the others have faded, the test passes!").pin
  end
  
end