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
        @fft_pending = []
        super
      end

      # Block until the next collection of data is ready.
      # Result is an array of Complex of the requested size.
      # I/Q sources process size*frequency bytes
      # LPCM sources process 2*size*frequency bytes and don't return the reflection
      # size must be a power of 2 (use GPU for visual scaling)
      # frequency may be greater or less than 1.0
      # This is not queued; missed processing is skipped.
      def fft size, frequency=1.0
        cur_fft_data = do_sleep = true
        @semaphore.synchronize do
          cur_fft_data = @fft_data
          if cur_fft_data[[size, frequency]]
            do_sleep = false 
          else
            @fft_pending[[size, frequency]] << Thread.current
          end
        end
        sleep if do_sleep
        cur_fft_data[[size, frequency]]
      end
  
      private
    
      def fft_collect samples
        time_now = Time.now
        @semaphore.synchronize do
          @fft_pending.keys.each do |size, frequency|
            @fft_buf[[size, frequency]] ||= []
            @fft_buf[[size, frequency]][0] = time_now
          end
          fft_expire = time_now - 10
          @fft_buf.delete_if { |k,v| v[0] < time_now }
          @fft_buf.each do |k,v|
            time, data, result = v
            size, frequency = k
            size *= 2 if Float == samples.first
            data.push samples
            buf_size = data.reduce(0){|a,b|a+b.size}
            size_freq = size*frequency
            if buf_size > size and buf_size > size_freq
              fft_process size, frequency
              trim_size = size - size_freq
              while buf_size > trim_size
                data.shift 
                buf_size = data.reduce(0){|a,b|a+b.size}
              end
            end
          end
        end
      end
    
      def fft_process size, frequency
        #TODO
      end

    end
  end
end