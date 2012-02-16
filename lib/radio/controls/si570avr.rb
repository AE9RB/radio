# Copyright 2012 The ham21/radio Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


class Radio
  module Controls

    # Support for Silicon Labs Si570 using Atmel AVR USB device.
    # see: http://pe0fko.nl/SR-V9-Si570/
    # For SoftRock KB9YIG radio kits et al.
    class Si570AVR
    
      RT_IN = LIBUSB::REQUEST_TYPE_VENDOR | LIBUSB::RECIPIENT_DEVICE | LIBUSB::ENDPOINT_IN
      RT_OUT = LIBUSB::REQUEST_TYPE_VENDOR | LIBUSB::RECIPIENT_DEVICE | LIBUSB::ENDPOINT_OUT
      DWELL = 0.1 #seconds

      def initialize options={}
        @divisor = options.delete(:divisor) || 4
        index = options.delete(:index) || 0
        @options = options
        if options.empty?
          @options[:idVendor] ||= 0x16c0
          @options[:idProduct] ||= 0x05dc
        end
        @device = LIBUSB::Context.new.devices(options)[index]
        raise 'USB Device Not Found' unless @device
      end
  
      def lo= freq
        data = [freq * (1<<21) * @divisor].pack('L')
        @device.open do |handle|
          handle.claim_interface(0)
          handle.control_transfer(
            :bmRequestType => RT_OUT, :bRequest => 0x32, 
            :wValue => 0, :wIndex => 0, :dataOut => data
          )
          handle.release_interface(0)
        end
        @lo = nil
      end
  
      def lo
        return @lo if @lo and Time.now < @lo_expires
        data = nil
        @device.open do |handle|
          handle.claim_interface 0
          data = handle.control_transfer(
            :bmRequestType => RT_IN, :bRequest => 0x3a, 
            :wValue => 0, :wIndex => 0, :dataIn => 4
          )
          handle.release_interface 0
        end
        @lo_expires = Time.now + DWELL
        @lo = (data.unpack('L')[0].to_f / (1<<21) / @divisor).round 6
      end
    
      def stop
        #noop
      end

    end
  end
    
end

