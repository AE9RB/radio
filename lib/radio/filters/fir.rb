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
      def setup data
        # ensure we don't accidentally use slower ops for 1:1
        @options.delete(:interpolate) if @options[:interpolate] == 1
        @options.delete(:decimate) if @options[:decimate] == 1.0
        coef = @options[:fir]
        # split array for when we interpolate and decimate in one step
        if @options[:interpolate] and @options[:decimate]
          @interpolation_fir_coef = coef[0]
          @decimation_fir_coef = coef[1]
        elsif @options[:interpolate]
          @interpolation_fir_coef = coef
        else # decimation (use for 1:1 too)
          @decimation_fir_coef = coef
        end
        # expand interpolation filter to multiple
        if @interpolation_fir_coef
          @interpolation_size = @options[:interpolate].to_i
          remainder = @interpolation_fir_coef.size % @interpolation_size
          if remainder > 0
            @interpolation_fir_coef = @interpolation_fir_coef.to_a 
            @interpolation_fir_coef += [0]*(@interpolation_size-remainder)
          end
        end
        # double up the coef for performance trick
        @interpolation_fir_coef = setup_build_coef @interpolation_fir_coef
        @decimation_fir_coef = setup_build_coef @decimation_fir_coef
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
          @decimation_fir_size = @decimation_fir_coef.size / 2
          @decimation_buf_f = NArray.sfloat @decimation_fir_size
          @decimation_buf_c = NArray.scomplex @decimation_fir_size
          @decimation_fir_pos = 0
          @decimation_size = @options[:decimate]
          if Float == @decimation_size
            @decimation_pos = 0.0
          else
            @decimation_pos = 0
          end
        end
        super
      end

      def setup_build_coef coef
        return nil unless coef
        if Complex === coef[0]
          new_coef = NArray.scomplex coef.size * 2
        else
          new_coef = NArray.sfloat coef.size * 2
        end
        new_coef[0...coef.size] = coef.to_a
        new_coef[coef.size..-1] = coef.to_a
        new_coef
      end

    end


    module SetupMix
      # This trick is slightly faster than cos/sin lookups.
      # @mix_phase *= @mix_phase_inc
      # Take out the rounding errors once in a while with:
      # @mix_phase /= @mix_phase.abs
      def setup data
        @mix_phase = Complex(1.0,1.0)/Complex(1.0,1.0).abs
        @mix_phase_inc = Math.exp(Complex(0, PI2 * @options[:mix]))
        super
      end
    end
    
    module ComplexEachMixDecimateFir
      include SetupFir
      include SetupMix

      #TODO better buffering et al
      def setup x
        @b = NArray.scomplex 256
        @bx = 0
        super
      end
      def call data
        @mix_phase /= @mix_phase.abs
        data.each do |sample|
          @decimation_fir_pos = @decimation_fir_size if @decimation_fir_pos == 0
          @decimation_fir_pos -= 1

          @mix_phase *= @mix_phase_inc
          @decimation_buf_c[@decimation_fir_pos] = sample * @mix_phase
          
          @decimation_pos -= 1
          if @decimation_pos <= 0
            @decimation_pos += @decimation_size
            f_start = @decimation_fir_size-@decimation_fir_pos
            f_end = -1-@decimation_fir_pos
            iq = @decimation_buf_c.mul_accum @decimation_fir_coef[f_start..f_end], 0
            
            @bx += 1
            if @bx == @b.size
              yield @b
              @bx = 0
            end
            @b[@bx] = iq
          end
        end
      end
    end
    
    module FloatEachMixDecimateFir
      include SetupFir
      include SetupMix
      def call data
        @mix_phase /= @mix_phase.abs
        data.each do |sample|
          @decimation_fir_pos = @decimation_fir_size if @decimation_fir_pos == 0
          @decimation_fir_pos -= 1
          
          @mix_phase *= @mix_phase_inc
          @decimation_buf_c[@decimation_fir_pos] = sample * @mix_phase
          
          @decimation_pos -= 1
          if @decimation_pos <= 0
            @decimation_pos += @decimation_size
            f_start = @decimation_fir_size-@decimation_fir_pos
            f_end = -1-@decimation_fir_pos
            iq = @decimation_buf_c.mul_accum @decimation_fir_coef[f_start..f_end], 0
            yield iq[0]
          end
        end
      end
    end
    
    module ComplexFir
      include SetupFir
      def call data
        @decimation_fir_pos = @decimation_fir_size if @decimation_fir_pos == 0
        @decimation_fir_pos -= 1
        @decimation_buf_c[@decimation_fir_pos] = data
        iq = @decimation_buf_c.mul_accum @decimation_fir_coef[@decimation_fir_size-@decimation_fir_pos..-1-@decimation_fir_pos], 0
        yield iq[0]
      end
    end
    
    module FloatEachInterpolateFir
      include SetupFir
      def call data
        out = NArray.float @interpolation_size, data.size
        index = 0
        data.each do |value|
          @interpolation_fir_pos = @interpolation_fir_size if @interpolation_fir_pos == 0
          @interpolation_fir_pos -= 1
          @interpolation_buf_f[@interpolation_fir_pos] = value
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