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
    
    class BitDetect
      
      AVG_SAMPLES = 50.freeze
      CHANGE_DELAY = 5
      
      def initialize
        @averages = Array.new 16
        reset
      end
      
      def reset
        @averages.fill 0.0
        @phase = 0
        @peak = 0
        @next_peak = 0
        @change_at = 0
      end
      
      def call sample_x, sample_y
        yield if @phase == @peak
        @peak = @next_peak if @phase == @change_at
        energy = sample_x**2 + sample_y**2
        @averages[@phase] = (1.0-1.0/AVG_SAMPLES)*@averages[@phase] + (1.0/AVG_SAMPLES)*energy
        @phase += 1
        if @phase > 15
          @phase = 0
          max = -1e10
          for i in 0...16
            energy = @averages[i]
            if energy > max
              @next_peak = i
              @change_at = (i + CHANGE_DELAY) & 0x0F
              max = energy
            end
          end
        end
      end
      
    end
    
  end
end
