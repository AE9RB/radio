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
  class Rig
    module Spectrum
  
      def initialize
        @spectrum_buf = {}
        @spectrum_semaphore = Mutex.new
        @spectrum_pending = Hash.new {|h,k|h[k]=[]}
        register @spectrum_queue = Queue.new
        Thread.start &method(:spectrum_collector)
        super
      end

      # Block until the next collection of data is ready (size*frequency samples).
      # Result is NArray of floats suitable for display purposes.
      # size must be a power of 2 for good performance (use GPU for visual scaling)
      # frequency may be greater or less than 1.0
      # keep_alive in secs set high enough so intervals between results are accurate
      # Results are not queued; missed processing is skipped.
      # This is meant to be an ideal interface for Web UI work, not signal analysis.
      def spectrum size, frequency=1.0, keep_alive=2.0
        @spectrum_semaphore.synchronize do
          @spectrum_pending[[size, frequency, keep_alive]] << Thread.current
        end
        sleep
        @spectrum_buf[[size, frequency, keep_alive]][2]
      end
  
      private
    
      def spectrum_collector
        begin
          loop do
            samples = @spectrum_queue.pop
            time_now = Time.now
            @spectrum_semaphore.synchronize do
              # Ensure buffers for all requested setups are in place
              @spectrum_pending.keys.each do |size, frequency, keep_alive|
                @spectrum_buf[[size, frequency, keep_alive]] ||= [nil,[],nil]
                @spectrum_buf[[size, frequency, keep_alive]][0] = time_now
              end
              # Stop running anything that's not being used anymore
              @spectrum_buf.delete_if { |k,v| v[0] < time_now - k[2] }
              # Handle the data for each active buffer
              @spectrum_buf.each do |k,v|
                time, data, result = v
                size, frequency, keep_alive = k
                collect_size = size * ((Float === samples[0]) ? 2 : 1)
                data.push samples
                buf_size = data.reduce(0){|a,b|a+b.size}
                size_freq = collect_size*frequency
                # Wait until we have enough data and the time is right
                if buf_size > collect_size and buf_size > size_freq
                  # Discard any extra data we won't use (frequency>1)
                  while buf_size - data.first.size > collect_size
                    buf_size -= data.shift.size
                  end
                  pending_key = [size, frequency, keep_alive]
                  if @spectrum_pending.has_key? pending_key
                    spectrum_data = NArray.to_na data
                    spectrum_data.reshape! spectrum_data.total
                    spectrum_out = FFTW3.fft(spectrum_data[-collect_size..-1]) 
                    if spectrum_out.size == size
                      result = NArray.sfloat size
                      result[0...size/2] = spectrum_out[size/2..-1].div!(size)
                      result[size/2..-1] = spectrum_out[0...size/2].div!(size)
                      v[2] = result.abs
                    else
                      v[2] = spectrum_out[0...size].div!(size).abs
                    end
                    @spectrum_pending[pending_key].each(&:wakeup)
                    @spectrum_pending.delete pending_key
                  end
                  # Discard enough old buffers to accommodate the frequency
                  trim_size = [0, collect_size - size*frequency].max
                  while buf_size > trim_size
                    buf_size -= data.shift.size
                  end
                end
              end
            end
          end
        rescue Exception => e
          p "ERROR #{e.message}: #{e.backtrace.first}" #TODO logger
          raise e
        end
      end
    
    end
  end
end

