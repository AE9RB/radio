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


require 'coreaudio'

class Radio
  module Inputs
    
    class CoreAudio
      
      # I don't see a way to automatically set the CoreAudio CODEC rate.
      # We'll present the nominal_rate as the only option.  This will trigger
      # the sample rate messages for the user if it's set to CD audio.
      def self.sources
        result = {}
        warnings = []
        ::CoreAudio.devices.each do |dev|
          clannels = dev.input_stream.channels
          if channels > 0
            result[dev.devid] = {
              name: dev.name,
              rates: [dev.nominal_rate],
              channels: channels
            }
          end
        end
        result
      end

      # Is the Rig doesn't see any suitable CODEC rate, it will ask here
      # for a sentence or two to append the user message.
      def self.help_for_rate_adjust
        'Use "Applications/Utilities/Audio MIDI Setup" to adjust.'
      end
      
      # id is the key from the sources hash.
      # rate is the desired hardware rate.  do not decimate/interpolate here.
      # samples are the quantity to be processed on each call.
      def initialize id, rate, samples, channel_i, channel_q=nil
        @device = CoreAudio::AudioDevice.new id
        raise 'sample rate mismatch' unless rate == @device.nominal_rate
        raise 'I channel fail' unless channel_i < @device.input_stream.channels
        @channel_i = channel_i
        channels = 1
        if channel_q
          raise 'Q channel fail' unless channel_q < @device.input_stream.channels
          @channel_q = channel_q
          extend IQ
          channels = 2
        end
        @samples = samples
        coreaudio_input_buffer_size = channels * samples * 3
        @buf = @dev.input_buffer coreaudio_input_buffer_size
        @buf.start
      end

      # This is called on its own thread in Rig and is expected to block.
      # until it can return a full array of floats (-1..1).
      def call
        # CoreAudio range of -32767..32767 makes easy conversion to -1.0..1.0
        @buf.read(@samples)[@channel_i,true].to_f/32767
      end
      
      # Once killed, no starting again on this object.
      def kill
        @buf.kill
      end

      module IQ
        def call
          #TODO optimized yield array of complex
        end
      end
      
    end

    #TODO thinking about this...
    # Inputs.register CoreAudio
    
  end
end
