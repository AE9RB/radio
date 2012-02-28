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
      private
      
      def setup data
        # ensure we don't accidentally use slower ops for 1:1
        @options.delete(:interpolate) if @options[:interpolate] == 1
        @options.delete(:decimate) if @options[:decimate] == 1.0
        # split array for when we interpolate and decimate in one step
        coef = @options[:fir] # use a [1] for half
        mix = @options[:mix] # use a zero for half
        if @options[:interpolate] and @options[:decimate]
          if coef
            @interpolation_fir_coef = coef[0]
            @decimation_fir_coef = coef[1]
          end
          if mix
            @interpolation_mix = mix[0]
            @decimation_mix = mix[1]
          end
        elsif @options[:interpolate]
          @interpolation_mix = mix
          @interpolation_fir_coef = coef
        else # decimation (use for 1:1 too)
          @decimation_mix = mix
          @decimation_fir_coef = coef
        end
        # expand interpolation filter for matrix by padding with 0
        if @interpolation_fir_coef
          @interpolation_size = @options[:interpolate].to_i
          remainder = @interpolation_fir_coef.size % @interpolation_size
          if remainder > 0
            @interpolation_fir_coef = @interpolation_fir_coef.to_a 
            @interpolation_fir_coef += [0]*(@interpolation_size-remainder)
          end
        end
        # prepare coef with performance tricks
        @interpolation_fir_coef = setup_build_coef @interpolation_fir_coef, @interpolation_mix
        @decimation_fir_coef = setup_build_coef @decimation_fir_coef, @decimation_mix
        # interpolation is shaped to avoid 0*0 ops
        if @interpolation_fir_coef
          @interpolation_fir_size = @interpolation_fir_coef.size / 2 / @interpolation_size
          @interpolation_buf_f = NArray.sfloat @interpolation_fir_size
          @interpolation_buf_c = NArray.scomplex @interpolation_fir_size
          @interpolation_fir_pos = 0
          ranks = @interpolation_fir_coef.size / @interpolation_size
          coef = @interpolation_fir_coef.reshape(@interpolation_size, ranks)
          @interpolation_fir_coef = NArray.new(coef.typecode, ranks, @interpolation_size)
          @interpolation_size.times {|rank| @interpolation_fir_coef[true,rank] = coef[rank,true]}
        end
        # decimation allows fractions for digital work
        if @decimation_fir_coef
          @decimation_size = @options[:decimate]
          if Float === @decimation_size
            @decimation_pos = 0.0
          else
            @decimation_pos = 0
          end
          @decimation_fir_size = @decimation_fir_coef.size / 2
          @decimation_buf = NArray.scomplex @decimation_fir_size
          @decimation_fir_pos = 0
        end
        if @decimation_mix
          @decimation_phase, @decimation_inc = 
            setup_new_mixer @decimation_mix, @decimation_size
        end
        if @interpolation_mix
          @interpolation_phase, @interpolation_inc = 
            setup_new_mixer @interpolation_mix, @interpolation_size
        end
        super
      end
      
      def setup_new_mixer mix, size
        return [Complex(1.0,1.0)/Complex(1.0,1.0).abs,
                Math.exp(Complex(0, PI2 * mix * size))]
      end
      
      def setup_build_coef coef, mix
        return nil unless coef
        coef = coef.to_a.reverse
        if mix
          # The signal is pre-mixed into the filter.
          # We adjust the master phase every time we filter.
          # mix_phase *= mix_phase_inc # faster than sin+cos
          # Take out the rounding errors once in a while with:
          # mix_phase /= mix_phase.abs
          rate = PI2 * mix
          i = -1
          coef.collect! do |coef|
            i += 1
            coef * Math.exp(Complex(0,rate*i))
          end
        end
        if Complex === coef[0]
          new_coef = NArray.scomplex coef.size * 2
        else
          new_coef = NArray.sfloat coef.size * 2
        end
        new_coef[0...coef.size] = coef
        new_coef[coef.size..-1] = coef
        new_coef
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