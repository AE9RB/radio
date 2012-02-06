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
  module Input

    class ALSA
      
      def self.status
        if defined? ::ALSA::PCM
          return "Loaded: %d input devices" % sources.count
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
      
      def self.sources
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
              channels: params.channels
            }
          end rescue nil
        end
        result
      end
      
      attr_reader :rate, :channels
      
      def initialize id, rate, channel_i, channel_q
        @stream = ::ALSA::PCM::Capture.new
        @stream.open id
        @rate = @stream.hardware_parameters.sample_rate
        @channels = @stream.hardware_parameters.channels
      end
      
      def call samples
        raise 'TODO: not quite done yet'
      end
      
      def stop
        @stream.close
      end
      
    end
    
  end
end

