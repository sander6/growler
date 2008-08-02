require 'lib/growler'

class Hash
  def debug(options = {})
    skipped_keys = options[:skip].nil? ? [] : options[:skip].is_a?(Array) ? options[:skip] : [options[:skip]]
    each do |key, value|
      puts ":#{key} => #{value}" unless skipped_keys.include?(key)
    end
  end
end

# 10.times { Growl.post(:title => "Rat-tat-tat-tat!", :message => "Machine gun testing!") }

# Growl.title("Test One Go!").message("First test notification from Growl module!")
# Growl.post

app = Growl.application do |growl|
  growl.name = "TestGrowler"
  growl.app_icon = "Things"
  growl.notification do |note|
    note.name = "Test Notification Dos"
    note.title = "Test Two Go!"
    note.message = "Second test notification from Growl::Application!"
    note.when_clicked do
      puts "Test Notification Dos totally got clicked on, fool."
    end
    note.when_timed_out do
      puts "Test Notification Dos totally timed out. You weren't fast enough to save it."
    end
  end
  growl.notification do |note|
    note.name = "Test Notification Tres"
    note.title = "Test Three Go!"
    note.message = "Third test notification from Growl::Application! This one's sticky!"
    note.sticky = true
    note.app_icon = "iTunes"
  end
  growl.notification do |note|
    note.name = "Machine Gun Test"
    note.title = "Rat-tat-tat-tat! Rat-tat-tat Like That!"
    note.message = "Machine gun testing TestGrowler!"
    note.sticky = true
    note.when_clicked do
      puts "Dakka dakka!"
    end
  end
end



# # note_two = app["Test Notification Dos"]
# # note_two.post

note_three = app["Test Notification Tres"]
note_three.when_clicked do
  puts "Test Notification Tres totally got clicked on, B."
end

note_three.post
puts
puts

note_three.post(:sticky => false)
note_three.post(:title => "Hooray!")
note_three.post(:message => "Not really working, eh?")

note_three.send(:build_notification_data).to_ruby.debug(:skip => "NotificationIcon")

# # app["Test Notification Dos"].post
# # app["Test Notification Tres"].post
# # app["Test Notification Dos"].post(:title => "Test Four Go!", :message => "Actually test two, but with sticky override!", :sticky => true)
# app["Test Notification Tres"].post(:title => "Test Five Go!", :message => "Actually test three, but with a different icon!", :app_icon => "iTunes")
# # 
# # app.each {|note| note.post(:sticky => false)}
# # 
# # 10.times { app["Machine Gun Test"].post }
# 

# OSX::NSThread.alloc.initWithTarget_selector_object(OSX::NSApp, "run", nil)
# OSX::NSThread.detachNewThreadSelector_toTarget_withObject("run", OSX::NSApplication.sharedApplication, nil)

# while true do
#   str = gets
#   if str =~ /stop/
#     puts "okay"
#     break
#   end
#   puts str
# end
  
  
app.start!