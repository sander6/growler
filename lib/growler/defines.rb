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

module Growl

  # These are the various strings Growl uses to recognize certain events.
  # I didn't make these up.
  GROWL_IS_READY = "Lend Me Some Sugar; I Am Your Neighbor!"
  GROWL_PING = "Honey, Mind Taking Out The Trash"
  GROWL_PONG = "What Do You Want From Me, Woman"
  GROWL_NOTIFICATION_CLICKED = "GrowlClicked!"
  GROWL_NOTIFICATION_TIMED_OUT = "GrowlTimedOut!"
  GROWL_KEY_CLICKED_CONTEXT = "ClickedContext"

  # Path to the Growl.framework in the ext directory.
  BUNDLE_PATH = File.join(File.dirname(__FILE__), "..", "..", "ext", "Growl.framework")
  
  # Are we on a Mac? If not, let's account for all that.
  MAC = !!(RUBY_PLATFORM =~ /darwin/)
  
  # Do we have access to RubyCocoa? If so, the Mac versions of Application and Notification
  # will be loaded, along with the ImageExtractor and other RubyCocoa-dependent libraries
  # and features. If not, non-RubyCocoa versions of Application and Notification will be loaded
  # and Growler should be able to serve as a remote notification sending system.
  COCOA = if MAC
            begin
              require 'osx/cocoa'
            rescue LoadError
              false
            end
          else
            false
          end

  protected
  
  # As I understand it, the Ruby that comes with Tiger has a broken implementation of
  # Array#pack. This will get around that by fixing the format to be correct.
  def self.fix_broken_pack(format)
    BROKEN_PACK ? format.gsub(/n/, 'v') : format
  end

  public

  # The following are borrowed (i.e. plagarized) from Eric Hodel's Ruby-Growl.
  BROKEN_PACK = [1].pack("n") != "\000\001"
  GROWL_NETWORK_REGISTRATION_FORMAT = fix_broken_pack("CCnCCa*")
  GROWL_NETWORK_NOTIFICATION_FORMAT = fix_broken_pack("CCnnnnna*")
  
  # Various constants that Growl is looking for when receiving a network registration or
  # notification packet to understand the protocol version and authentication type.
  # Read more than you ever wanted to know about Growl's network protocol format at
  # http://growl.info/documentation/developer/protocol.php
  UDP_PORT = 9887
  PROTOCOL_VERSION = 1
  PROTOCOL_VERSION_AES128 = 2
  TYPE_REGISTRATION = 0
  TYPE_NOTIFICATION = 1
  TYPE_REGISTRATION_SHA256 = 2
  TYPE_NOTIFICATION_SHA256 = 3
  TYPE_REGISTRATION_NOAUTH = 4
  TYPE_NOTIFICATION_NOAUTH = 5
  
end