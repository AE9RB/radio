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
  module Signal

    class CoreAudio
      
      JITTER = 0.15 #seconds of window for output timing jitter
      BUFFER = 0.5 #seconds of input buffer

      begin
        # Older versions have a one-off bug in audio output
        # which will cause spurious emissions if used to transmit.
        gem 'coreaudio', '>= 0.0.8'
        require 'coreaudio'
      rescue LoadError => e
        @bad_coreaudio = gem 'coreaudio'
      end
      
      def self.status
        if defined? ::CoreAudio
          return "Loaded: %d devices" % devices.count
        end
        unless defined? @is_darwin
          @is_darwin = (`uname`.strip == 'Darwin') rescue false
        end
        return 'Unsupported: requires Apple OS' unless @is_darwin
        return 'Unavailable: gem update coreaudio ">= 0.0.8"' if @bad_coreaudio
        return 'Unavailable: gem install coreaudio'
      end
  
      # I don't see a way to automatically set the CoreAudio CODEC rate.
      # We'll present the nominal_rate as the only option.
      def self.devices
        return {} unless defined? ::CoreAudio
        result = {}
        ::CoreAudio.devices.each do |dev|
          result[dev.devid] = {
            name: dev.name,
            rates: [dev.nominal_rate.to_i],
            input: dev.input_stream.channels,
            output: dev.output_stream.channels,
          }
        end
        result
      end
      
      attr_reader :input_channels, :output_channels

      def initialize options 
        @device = ::CoreAudio::AudioDevice.new options[:id].to_i
        @input_channels = @output_channels = 0
        if @input = options[:input]
          @input_channels = @input.size
          buffer_size = @input_channels * rate * BUFFER
          @input_buf = @device.input_buffer buffer_size
          @input_buf.start
        end
        if @output = options[:output]
          @output_channels = @output.size
          buffer_size = @output_channels * rate * JITTER * 2
          @output_buf = @device.output_buffer buffer_size
          @output_buf.start
        end
      end

      # This is called on its own thread in Rig and is expected to block.
      def in samples
        # CoreAudio range of -32767..32767 makes easy conversion to -1.0..1.0
        if @input_channels == 1
          @input_buf.read(samples)[@input[0],true].to_f.div!(32767)
        else
          b = @input_buf.read samples
          c_out = NArray.scomplex samples
          c_out[0..-1] = b[@input[0],true].to_f.div!(32767)
          c_out.imag = b[@input[1],true].to_f.div!(32767)
          c_out
        end
      end
      
      def out data
        resetting = false
        if @output_buf.dropped_frame > 0
          p 'sleeping because frame dropped' #TODO logger
          resetting = true
          sleep JITTER
        end
        out = nil
        if @drop_data
          if @drop_data < data.size
            out = data[@drop_data..-1] * 32767
          end
          @drop_data -= data.size
          @drop_data = nil if @drop_data <= 0
        else
          out = data * 32767
        end
        if out
          # CoreAudio gem will block when the buffer is full
          # We'll discard a jitter worth of data when this happens
          jit = Time.now + 0.01
          @output_buf << out
          if Time.now > jit
            p 'dropping some data' #TODO logger
            @drop_data = rate * JITTER
          end
        end
        @output_buf.reset_dropped_frame if resetting
      end
  
      # Once stopped, rig won't attempt starting again on this object.
      def stop
        @input_buf.stop if @input_buf
        @output_buf.stop if @output_buf
      end
      
      def rate
        @device.nominal_rate
      end
      
    end

  end
end
