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
    
    include FFT
    include Rx
  
    def initialize
      @semaphore = Mutex.new
      super
      
      @device = Audio.inputs[0]
      @queue = @device.subscribe
      @semaphore = Mutex.new
      @thread = Thread.new &method(:thread)
      @waterfall = Queue.new
      @waterfall_pending = 0
    end

    def waterfall_row
      @semaphore.synchronize { @waterfall_pending += 1 }
      @waterfall.pop
    end
    
    def thread
      fft_count = 0
      fft_data = []
      loop do
        data = @queue.pop
        fft_count += 1
        fft_data += data.to_a
        if fft_count == 4
          fftval = FFTW3.fft(fft_data, 0)
          # 716 == 0-2800Hz SSB
          waterfall_data = Array.new
          fftval[0...716].each do |v|
            waterfall_data << Math.hypot(v.real, v.imag)
          end
          gif = WaterfallGif.gif([waterfall_data])
          waterfall_pending = nil
          @semaphore.synchronize do
            waterfall_pending = @waterfall_pending
            @waterfall_pending = 0
          end
          waterfall_pending.times { @waterfall.push gif }
          fft_count = 0
          fft_data = []
        end
      end
    end
  
  end
end