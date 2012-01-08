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
  class Filter
    
    module FirSetup
      # It's ok that not all filter patterns use all instance variables.
      def setup data
        @mix_phase = 0.0
        @mix_phase_inc = @options[:mix]
        @dec_pos = @dec_size = @options[:decimate]
        coef = @options[:fir]
        @fir_pos = 0
        @fir_size = coef.size
        @fir_coef = NArray.to_na coef.reverse*2
        @fir_buf = NArray.complex @fir_size
        super
      end
    end

    module FloatNArrayMixDecimateFir
      include FirSetup
      def call data
        data.each do |energy|
          @fir_pos = @fir_size if @fir_pos == 0
          @fir_pos -= 1
          @fir_buf[@fir_pos] = Complex(Math.sin(@mix_phase)*energy, -Math.cos(@mix_phase)*energy)
          @mix_phase += @mix_phase_inc
          @mix_phase -= PI2 if @mix_phase >= PI2
          @dec_pos -= 1
          if @dec_pos == 0
            @dec_pos = @dec_size
            iq = @fir_buf.mul_accum @fir_coef[@fir_size-@fir_pos..-1-@fir_pos],0
            yield iq[0]
          end
        end
      end
    end
    
    module ComplexFir
      include FirSetup
      def call data
        @fir_pos = @fir_size if @fir_pos == 0
        @fir_pos -= 1
        @fir_buf[@fir_pos] = data
        iq = @fir_buf.mul_accum @fir_coef[@fir_size-@fir_pos..-1-@fir_pos],0
        yield iq[0]
      end
    end
    
  end
end