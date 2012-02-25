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

    module SetupFirFloat
      def setup data
        coef = @options[:fir]
        @fir_pos = 0
        @fir_size = coef.size
        @fir_coef = NArray.sfloat @fir_size * 2 
        if Complex === coef[0]
          @fir_coef = coef.real*2
        else
          @fir_coef = coef*2
        end
        @fir_buf = NArray.float @fir_size
        super
      end
    end
    
    module SetupFirComplex
      def setup data
        coef = @options[:fir]
        @fir_pos = 0
        @fir_size = coef.size
        if Complex === coef[0]
          @fir_coef = NArray.scomplex @fir_size * 2
        else
          @fir_coef = NArray.sfloat @fir_size * 2
        end
        @fir_coef = coef*2
        @fir_buf = NArray.scomplex @fir_size
        super
      end
    end
    
    # do not include before fir setup
    module SetupInterpolateDecimate
      def setup data
        @dec_pos = @dec_size = @options[:decimate]
        @interpolate = @options[:interpolate]
        super
      end
    end
    
    module SetupMix
      def setup data
        @mix_phase = 0.0
        @mix_phase_inc = @options[:mix]
        super
      end
    end

    module FloatEachMixDecimateFir
      include SetupFirComplex
      include SetupMix
      include SetupInterpolateDecimate
      def call data
        data.each do |energy|
          @fir_pos = @fir_size if @fir_pos == 0
          @fir_pos -= 1
          @fir_buf[@fir_pos] = Complex(Math.cos(@mix_phase)*energy, -Math.sin(@mix_phase)*energy)
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
      include SetupFirComplex
      def call data
        @fir_pos = @fir_size if @fir_pos == 0
        @fir_pos -= 1
        @fir_buf[@fir_pos] = data
        iq = @fir_buf.mul_accum @fir_coef[@fir_size-@fir_pos..-1-@fir_pos],0
        yield iq[0]
      end
    end
    
    module FloatEachInterpolateFir
      include SetupFirFloat
      include SetupInterpolateDecimate
      #TODO reshape interpolate so we aren't mul_accum all those 0*0
      def call data
        out = NArray.float @interpolate, data.size
        out[0,true] = data
        @interpolate.times {|i| out[i,true] = data}
        out.reshape!(@interpolate * data.size)
        out.collect! do |value|
          @fir_pos = @fir_size if @fir_pos == 0
          @fir_pos -= 1
          @fir_buf[@fir_pos] = value
          iq = @fir_buf.mul_accum @fir_coef[@fir_size-@fir_pos..-1-@fir_pos],0
          iq[0]
        end
        yield out
      end
    end
    
  end
end