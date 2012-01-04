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
    
    class Decoder
      
      attr_accessor :mode # :bpsk or :qpsk or :qpsklsb
      
      def initialize
        @mode = :bpsk 
        reset
      end
      
      def reset
        @prev_i = 0.0
        @prev_q = 0.0
        @this_i = 0.0
        @this_q = 0.0
        @code = 0
        @prev_bit = false
      end
      
      def call new_i, new_q
        @prev_i = @this_i
        @prev_q = @this_q
        @this_i = new_i
        @this_q = new_q
        vect_y = @prev_i*@this_i + @prev_q*@this_q
        if @mode == :bpsk
          bit = vect_y >= 0.0 ? 1 : 0
        else
          vect_x = @prev_i*@this_q - @this_i*@prev_q
          if vect_y == 0.0 # atan2 errors on (0,0)
            angle = PI
          elsif @mode == :qpsklsb
            angle = PI + Math.atan2(vect_y, -vect_x)
          else # :qpsk or :bpsk
            angle = PI + Math.atan2(vect_y, vect_x)
          end
          bit = viterbi angle
        end
        if bit==0 and @prev_bit==0
          if @code != 0
            @code >>= 2
            @code &= 0x07FF
            ch = VARICODE_DECODE_TABLE[@code]
            yield ch if ch
            @code = 0
          end
        else
          @code <<= 1
          @code |= bit
          @prev_bit = bit
        end
      end
      
      private
      
      def viterbi
        raise 'todo'
      end
      
    end

  end
end
