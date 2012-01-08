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

      def initialize frequency
        phase_inc = PI2 * frequency / 8000
        @dec_filter = Filter.new mix:phase_inc, decimate:16, fir:FIR_DEC16
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
