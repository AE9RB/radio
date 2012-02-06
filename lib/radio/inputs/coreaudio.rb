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


begin
  require 'coreaudio'
rescue LoadError => e
end


class Radio
  module Input

    class CoreAudio
      
      def self.status
        if defined? ::CoreAudio
          return "Loaded: %d input devices" % sources.count
        end
        unless defined? @is_darwin
          @is_darwin = (`uname`.strip == 'Darwin') rescue false
        end
        return "Unsupported: requires Apple OS" unless @is_darwin
        return 'Unavailable: gem install coreaudio'
      end
  
      # I don't see a way to automatically set the CoreAudio CODEC rate.
      # We'll present the nominal_rate as the only option.
      def self.sources
        return {} unless defined? ::CoreAudio
        result = {}
        ::CoreAudio.devices.each do |dev|
          channels = dev.input_stream.channels
          if channels > 0
            result[dev.devid] = {
              name: dev.name,
              rates: [dev.nominal_rate.to_i],
              channels: channels
            }
          end
        end
        result
      end
      
      attr_reader :rate, :channels

      # id is the key from the sources hash.
      # rate is the desired hardware rate.  do not decimate/interpolate here.
      def initialize id, rate, channel_i, channel_q
        @device = ::CoreAudio::AudioDevice.new id.to_i
        @rate = @device.nominal_rate
        raise 'I channel fail' unless channel_i < @device.input_stream.channels
        @channel_i = channel_i
        @channels = 1
        if channel_q
          raise 'Q channel fail' unless channel_q < @device.input_stream.channels
          @channel_q = channel_q
          extend IQ
          @channels = 2
        end
        # Half second of buffer
        coreaudio_input_buffer_size = @channels * rate / 2
        @buf = @device.input_buffer coreaudio_input_buffer_size
        @buf.start
      end

      # This is called on its own thread in Rig and is expected to block.
      def call samples
        # CoreAudio range of -32767..32767 makes easy conversion to -1.0..1.0
        @buf.read(samples)[@channel_i,true].to_f.div!(32767)
      end
  
      # Once stopped, rig won't attempt starting again on this object.
      def stop
        @buf.stop
      end

      module IQ
        def call samples
          b = @buf.read samples
          c_out = NArray.scomplex samples
          c_out[0..-1] = b[@channel_i,true].to_f.div!(32767)
          c_out.imag = b[@channel_q,true].to_f.div!(32767)
          c_out
        end
      end
  
    end

  end
end
