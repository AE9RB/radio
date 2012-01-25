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


require 'fftw3'

class Radio

  class Rig
    
    module FFT
  
      def initialize
        @fft_buf = {}
        @fft_pending = Hash.new {|h,k|h[k]=[]}
        super
      end

      # Block until the next collection of data is ready.
      # Result is an array of Complex of the requested size.
      # I/Q sources wait to process size*frequency samples
      # LPCM sources process 2*size*frequency samples and won't return the reflection
      # size must be a power of 2 for good performance (use GPU for visual scaling)
      # frequency may be greater or less than 1.0
      # keep_alive in secs set high enough so intervals between results are accurate
      # Results are not queued; missed processing is skipped.
      # This is meant to be an ideal interface for Web UI work, not signal analysis.
      def fft size, frequency=1.0, keep_alive=5.0
        @semaphore.synchronize do
          @fft_pending[[size, frequency, keep_alive]] << Thread.current
        end
        sleep
        @fft_buf[[size, frequency, keep_alive]][2]
      end
  
      private
    
      def fft_collect samples
        time_now = Time.now
        @semaphore.synchronize do
          # Ensure buffers for all requested setups are in place
          @fft_pending.keys.each do |size, frequency, keep_alive|
            @fft_buf[[size, frequency, keep_alive]] ||= [nil,[],[]]
            @fft_buf[[size, frequency, keep_alive]][0] = time_now
          end
          # Stop running anything that's not being used anymore
          @fft_buf.delete_if do |k,v|
            time, data, result = v
            size, frequency, keep_alive = k
            time < time_now - keep_alive
          end
          # Handle the data for each active buffer
          @fft_buf.each do |k,v|
            time, data, result = v
            size, frequency, keep_alive = k
            collect_size = size * ((Float === samples[0]) ? 2 : 1)
            data.push samples
            buf_size = data.reduce(0){|a,b|a+b.size}
            size_freq = collect_size*frequency
            # Wait until we have enough data and the time is right
            if buf_size > collect_size and buf_size > size_freq
              fft_data = NArray.to_na(data).reshape(buf_size)
              fft_out = FFTW3.fft(fft_data[-collect_size..-1], 0) 
              if fft_out.size == size
                v[2] = fft_out
              else
                v[2] = fft_out[0...size]
              end
              @fft_pending[[size, frequency, keep_alive]].each(&:wakeup)
              @fft_pending.delete([size, frequency, keep_alive])
              # Discard enough old buffers to accommodate the frequency
              trim_size = [0, collect_size - size_freq].max
              while buf_size > trim_size
                data.shift 
                buf_size = data.reduce(0){|a,b|a+b.size}
              end
            end
          end
        end
      end
    
    end
  end
end


if $0 == __FILE__
  # require_relative '../../radio'
  load '../../radio.rb'
  unless $ddone
    r = Radio::Rig.new
    i = Radio::Inputs.new Radio::Inputs.sources.first[0], 8000, 0
    r.rx = i
    p r.fft 2048, 4
    p r.fft 512, 1, 2
    p r.fft 1024
    p r.fft 512, 1, 2
    p r.fft(2048, 4)[700..725]
    p r.fft(2048, 4)[700..725]
    p r.fft(2048, 4)[700..725]
  end
  $ddone=true
  # sleep 2
  # p r.rx= nil
end
