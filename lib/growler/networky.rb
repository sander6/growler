# Code contained herein is in whole or part adapted from previous work
# by Eric Hodel. Its modified redistribution is pursuant to the following
# license replicated in whole below. The author makes no claim, implied or
# otherwise, of endorsement or acknowledgement of this work by the original
# author.
# 
# Copyright 2004 Eric Hodel.  All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the names of the authors nor the names of their contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


require 'md5'
require 'socket'

module Growl
  module DataSender
    
    protected
    
    # Sends some data.    
    def send_data!(data)
      set_send_buffer(data.length) 
      @socket.send data, 0
      @socket.flush
    end
    
    # Builds an MD5 checksum given the supplied data and an optional password.
    def build_checksum(data, password = nil)
      checksum = MD5.new data
      checksum.update password unless password.nil?
      return checksum.digest
    end
    
    # I'll admit that I don't know what this does, since it was adapted (i.e. ripped off)
    # of Eric Hodels' Ruby-Growl. Even he admits that it might not be necessary, but I'm
    # certainly not qualified to make any judgments about that.
    def set_send_buffer(length)
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, length)
    end

  end
  
  # The Network module provides network functionality to Applications and Notifications.
  module Network
    
    # The Network::Application module gives Growl::Applications the ability to register
    # themselves remotely to other hosts. It is included in both flavors of the Application
    # class (both OSXy and non-OSXy).
    module Application

      # Ensures that the class this module is included in also gets the DataSender module.      
      def self.included(base)
        base.send :include, Growl::DataSender
      end
        
      private
    
      # Arduously builds the packet for remote application registration. The host you're
      # sending to must have "Allow remote application registration" checked in the Growl
      # preference pane.
      def build_registration_packet(password = nil)
        length = 0
        data = []
        data_format = ""
      
        packet = [Growl::PROTOCOL_VERSION, Growl::TYPE_REGISTRATION]
      
        packet << @name.size
        packet << @all_notifications.size
        packet << @default_notifications.size
      
        data << @name
        data_format << "a#{@name.size}"
      
        all_notification_names = @all_notifications.collect {|n| n[:name]}
        all_notification_names.each do |note_name|
          data << note_name.size
          data << note_name
          data_format << "na#{note_name.size}"
        end
      
        default_notification_names = @default_notifications.collect {|n| n[:name]}
        default_notification_names.each do |note_name|
          data << all_notification_names.index(note_name)
          data_format << "C"
        end
      
        data_format = Growl.fix_broken_pack(data_format)
      
        packet = (packet << data.pack(data_format)).pack(Growl::GROWL_NETWORK_REGISTRATION_FORMAT)

        packet << build_checksum(packet, password)
      
        return packet
      end
    end
  
    # The Growl::Network::Notification module allows Notifications (of both the OSXy and non-OSXy
    # types) to post remotely.
    module Notification

      # Ensures that the class this module is included in also gets the DataSender module.
      def self.included(base)
        base.send :include, Growl::DataSender
      end
  
      private
  
      # Arduously builds the packet to remotely post a notification through Growl. The host you're
      # posting to must have "Listen for incoming notifications" checked in it's Growl preference
      # pane.
      def build_notification_packet(*args)
        overrides = args.last.is_a?(Hash) ? args.pop : {}
        password = args[0]
        flags = 0
        data = []
    
        packet = [Growl::PROTOCOL_VERSION, Growl::TYPE_NOTIFICATION]    
        
        tmp_name = overrides[:name] || @name
        tmp_title = overrides[:title] || @title
        tmp_title = tmp_title.render(overrides) if tmp_title.is_a?(DynamicString) 
        tmp_message = overrides[:message] || @message
        tmp_message = tmp_message.render(overrides) if tmp_message.is_a?(DynamicString) 
        tmp_app_name = overrides[:app_name] || application_name
        tmp_priority = overrides[:priority] || @priority
        tmp_sticky = overrides[:sticky].nil? ? (@sticky.nil? ? false : @sticky) : overrides[:sticky]
    
        flags |= ((0x7 & tmp_priority) << 1)
        flags |= 1 if tmp_sticky

        packet << flags << tmp_name.size << tmp_title.size << tmp_message.size << tmp_app_name.size
        data << tmp_name << tmp_title << tmp_message << tmp_app_name
    
        packet << data.join
        packet = packet.pack(Growl::GROWL_NETWORK_NOTIFICATION_FORMAT)
    
        packet << build_checksum(packet, password)
    
        return packet
      end
  
    end
  end
end