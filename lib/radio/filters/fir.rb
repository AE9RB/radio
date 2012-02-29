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

    module SetupFir
      
      def interpolation_mix= mix
        @interpolation_mix = mix
        @interpolation_phase, @interpolation_inc = 
          new_mixer @interpolation_mix, @interpolation_size
        setup_interpolation if @interpolation_fir_orig
      end

      def interpolation_fir= coef
        remainder = coef.size % @interpolation_size
        # expand interpolation filter for matrix by padding with 0s
        if remainder > 0
          coef = coef.to_a + [0]*(@interpolation_size-remainder)
        end
        if @interpolation_fir_orig
          raise "can't grow filter" if coef.size > @interpolation_fir_orig.size
        else
          @interpolation_fir_size = coef.size / @interpolation_size
          @interpolation_buf_f = NArray.sfloat @interpolation_fir_size
          @interpolation_buf_c = NArray.scomplex @interpolation_fir_size
        end
        @interpolation_fir_orig = coef
        setup_interpolation
      end
      
      def decimation_mix= mix
        @decimation_mix = mix
        @decimation_phase, @decimation_inc = 
          new_mixer @decimation_mix, @decimation_size
        setup_decimation if @decimation_fir_orig
      end
      
      def decimation_fir= coef
        if @decimation_fir_orig
          raise "can't grow filter" if coef.size > @decimation_fir_orig.size
        else
          @decimation_fir_size = coef.size
          @decimation_buf = NArray.scomplex @decimation_fir_size
          # decimation allows fractions for digital work
          if Float === @decimation_size
            @decimation_pos = 0.0
          else
            @decimation_pos = 0
          end
        end
        @decimation_fir_orig = coef
        setup_decimation
      end
      
      private
      
      def setup data
        if @interpolation_size = @options[:interpolate]
          @interpolation_size = @interpolation_size.to_i
        end
        @decimation_size = @options[:decimate]
        if mix = @options[:mix]
          if @interpolation_size and @decimation_size
            self.interpolation_mix = mix[0]
            self.decimation_mix = mix[1]
          elsif @interpolation_size
            self.interpolation_mix = mix
          else
            self.decimation_mix = mix
          end
        end
        if coef = @options[:fir]
          if @interpolation_size and @decimation_size
            self.interpolation_fir = coef[0]
            self.decimation_fir = coef[1]
          elsif @interpolation_size
            self.interpolation_fir = coef
          else # decimation (use for 1:1 too)
            self.decimation_fir = coef
          end
        end
        super
      end
      
      def setup_interpolation
        coef = premix_filter @interpolation_fir_orig, @interpolation_mix
        @interpolation_fir_pos = 0
        @interpolation_fir_coef = double_filter coef
        # interpolation is shaped to avoid 0*0 ops
        ranks = @interpolation_fir_coef.size / @interpolation_size
        coef = @interpolation_fir_coef.reshape(@interpolation_size, ranks)
        @interpolation_fir_coef.reshape!(ranks, @interpolation_size)
        @interpolation_size.times {|rank| @interpolation_fir_coef[true,rank] = coef[rank,true]}
      end

      def setup_decimation
        coef = premix_filter @decimation_fir_orig, @decimation_mix
        @decimation_fir_pos = 0
        @decimation_fir_coef = double_filter coef
      end
      
      # We build filters with two copies of data so a
      # circular buffer can mul_accum on a slice.
      def double_filter coef
        coef = coef.to_a.reverse
        if Complex === coef[0]
          new_coef = NArray.scomplex coef.size * 2
        else
          new_coef = NArray.sfloat coef.size * 2
        end
        new_coef[0...coef.size] = coef
        new_coef[coef.size..-1] = coef
        new_coef
      end
      
      # The signal is pre-mixed into the filter.
      # We adjust the master phase every time we filter.
      # mix_phase *= mix_phase_inc # faster than sin+cos
      # Take out the rounding errors once in a while with:
      # mix_phase /= mix_phase.abs
      def premix_filter coef, mix
        return coef unless mix and mix != 0
        rate = PI2 * mix
        i = coef.size
        coef.collect do |coef|
          i -= 1
          coef * Math.exp(Complex(0,rate*i))
        end
      end
      
      def new_mixer mix, size
        return [Complex(1.0,1.0)/Complex(1.0,1.0).abs,
                Math.exp(Complex(0, PI2 * mix * size))]
      end

    end


    module ComplexMixDecimateFir
      include SetupFir
      def call data
        @decimation_phase /= @decimation_phase.abs
        out_size = data.size / @decimation_size
        out_size += 1 if @decimation_pos < (data.size % @decimation_size)
        out = NArray.scomplex out_size
        out_count = 0
        i = 0
        while i < data.size
          want = (@decimation_size - @decimation_pos).round
          remaining = data.size - i
          space = @decimation_fir_size - @decimation_fir_pos
          actual = [want,remaining,space].min
          new_fir_pos = @decimation_fir_pos + actual
          if actual == 1
            @decimation_buf[@decimation_fir_pos] = data[i]
          else
            @decimation_buf[@decimation_fir_pos...new_fir_pos] = data[i...i+actual]
          end
          @decimation_fir_pos = new_fir_pos
          @decimation_fir_pos = 0 if @decimation_fir_pos == @decimation_fir_size
          @decimation_pos += actual
          if @decimation_pos >= @decimation_size
            @decimation_pos -= @decimation_size
            f_start = @decimation_fir_size-@decimation_fir_pos
            f_end = -1-@decimation_fir_pos
            j = @decimation_buf.mul_accum @decimation_fir_coef[f_start..f_end], 0
            out[out_count] = j * @decimation_phase *= @decimation_inc
            out_count += 1
          end
          i += actual
        end
        yield out
      end
    end

    # So this is weird.  The complex version is faster than
    # storing just the real part.  Can use the same code for
    # both until the day this tests faster:
    # @decimation_buf = NArray.sfloat @decimation_fir_size
    FloatMixDecimateFir = ComplexMixDecimateFir

    module ComplexFir
      include SetupFir
      def call data
        out = NArray.scomplex data.size
        data.size.times do |i|
          @decimation_fir_pos = @decimation_fir_size if @decimation_fir_pos == 0
          @decimation_fir_pos -= 1
          @decimation_buf[@decimation_fir_pos] = data[i..i]
          f_start = @decimation_fir_size-@decimation_fir_pos
          f_end = -1-@decimation_fir_pos
          out[i] = @decimation_buf.mul_accum @decimation_fir_coef[f_start..f_end], 0
        end
        yield out
      end
    end
    
    module FloatInterpolateFir
      include SetupFir
      def call data
        out = NArray.float @interpolation_size, data.size
        index = 0
        data.each do |value|
          @interpolation_buf_f[@interpolation_fir_pos] = value
          @interpolation_fir_pos += 1
          @interpolation_fir_pos = 0 if @interpolation_fir_pos == @interpolation_fir_size
          f_start = @interpolation_fir_size-@interpolation_fir_pos
          f_end = -1-@interpolation_fir_pos
          iq = @interpolation_fir_coef[f_start..f_end, true].mul_accum @interpolation_buf_f, 0
          out[true,index] = iq.reshape!(iq.size).mul!(@interpolation_size)
          index += 1
        end
        yield out.reshape!(out.size)
      end
    end
    
  end
end