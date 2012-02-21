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
  
  class PSK31
    
    class Rx
      
      # 16 Hz bw LP filter for data recovery
      FIR_BIT = Radio::Remez.new numtaps: 65, type: :bandpass,
        bands: [0.0,0.03125,0.0625,0.5], desired: [1.0, 0.000001], weights: [1,286]

      def initialize frequency
        phase_inc = PI2 * frequency / 8000
        fir_500hz = Radio::Remez.new numtaps: 35, type: :bandpass,
          bands: [0,0.0125,0.125,0.5], desired: [1.0, 0.000001], weights: [1,10]
        @dec_filter = Filter.new mix:phase_inc, decimate:16, fir:fir_500hz
        @bit_filter = Filter.new fir:FIR_BIT
        @bit_detect = BitDetect.new
        @decoder = Decoder.new
      end
      
      def call data
        decoded = ''
        @dec_filter.call data do |iq|
          @bit_filter.call iq do |iq|
            @bit_detect.call iq do |iq|
              @decoder.call iq do |symbol|
                decoded += symbol
              end
            end
          end
        end
        yield decoded
      end
      
    end
    
  end
end
