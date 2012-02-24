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
  require 'alsa'
rescue LoadError => e
end


class Radio
  module Signal

    class ALSA
      
      def self.status
        if defined? ::ALSA::PCM
          return "Loaded: %d devices" % devices.count
        end
        unless defined? @is_linux
          @is_linux = (`uname`.strip == 'Linux') rescue false
        end
        return "Unsupported: requires Linux" unless @is_linux
        if defined? ::ALSA
          'Unavailable: install ALSA to your OS'
        else
          'Unavailable: gem install ruby-alsa'
        end
      end
      
      CP_REGEX = /:\s*(capture|playback)\s*(\d+)\s*$/
      CD_REGEX = /^(\d+)-(\d+):\s*/
      
      def self.devices
        return {} unless defined? ::ALSA::PCM
        # Funky read to get around old Linux bug
        # http://kerneltrap.org/mailarchive/git-commits-head/2009/4/17/5510664
        pcm = ::File.open('/proc/asound/pcm') do |io|
          io.read_nonblock 32768
        end
        result = {}
        pcm.each_line do |line|
          capture = 0
          2.times do
            line.gsub! CP_REGEX, ''
            capture = $2.to_i if $1 == 'capture'
          end
          line.gsub! CD_REGEX, ''
          device = "hw:#{$1.to_i},#{$2.to_i}"
          ::ALSA::PCM::Capture.open(device) do |stream|
            params = stream.hardware_parameters
            result[device] = {
              name: line,
              rates: [params.sample_rate],
              input: params.channels,
              output: 0
            }
          end rescue nil
        end
        result
      end
      
      def initialize options
        @stream = ::ALSA::PCM::Capture.new
        @stream.open options[:id]
        if input = options[:input]
          @channel_i = input[0]
          @channel_q = input[1]
        end
      end
      
      def rate
        @stream.hardware_parameters.sample_rate
      end
      
      def input_channels
        return 2 if @channel_q and @stream.hardware_parameters.channels > 1
        1
      end
      
      def output_channels
        0
      end
      
      def in samples
        out=nil
        buf_size = @stream.hw_params.buffer_size_for(samples)
        FFI::MemoryPointer.new(:char, buf_size) do |buffer|
          @stream.read_buffer buffer, samples
          out = buffer.read_string(buf_size)
          NArray.to_na(out, NArray::SINT).to_f.div! 32767
        end
        stream_channels = @stream.hardware_parameters.channels
        sample_size = buf_size / samples / stream_channels
        out = case sample_size
        when 1 then NArray.to_na(out,NArray::BYTE).to_f.collect!{|v|(v-128)/127}
        when 2 then NArray.to_na(out,NArray::SINT).to_f.div! 32767
        # when 3 then NArray.to_na(d,NArray::???).to_f.collect!{|v|(v-8388608)/8388607}
        else
          raise "Unsupported sample size: #{@sample_size}" 
        end
        return out if channels == 1 and stream_channels == 1
        out.reshape! stream_channels, out.size/stream_channels
        if channels == 1
          out[@channel_i,true]
        else
          c_out = NArray.scomplex out[0,true].size
          c_out[0..-1] = out[@channel_i,true]
          c_out.imag = out[@channel_q,true]
          c_out
        end
      end
      
      def stop
        @stream.close
      end
      
    end
    
  end
end
