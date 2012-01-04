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

      def initialize frequency, ppm_adjust=0
        @filter = Filters.new frequency, FIR_DEC, FIR_BIT
        @bit_detect = BitDetect.new
        @decoder = Decoder.new
        adjust_clock ppm_adjust
      end
      
      # samples are enumerable floats
      def call sample_data
        decoded = ''
        @filter.call sample_data do |i, q|
          @bit_detect.call i, q do
            @decoder.call i, q do |symbol|
              decoded += symbol
            end
          end
        end
        decoded
      end
      
      def frequency= frequency
        unless frequency == @filter.frequency
          @filter.frequency = frequency
          recalc_phase_inc
          reset
        end
      end
      
      # To compensate for bad clock in A-D conversion
      def adjust_clock ppm
        @clock = 8000.0 * ppm / 1000000 + 8000
        recalc_phase_inc
      end
      
      def reset
        @filter.reset
        @bit_detect.reset
        @decoder.reset
      end
      
      def recalc_phase_inc
        @filter.phase_inc = PI2 * @filter.frequency / @clock
      end
      
    end
    
  end
end
