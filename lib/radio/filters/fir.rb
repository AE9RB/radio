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
        @interpolation_fir_pos = 0 # sync to mixer
        @interpolation_phase, @interpolation_inc = 
          new_mixer @interpolation_mix, @interpolation_size
        setup_interpolation if @interpolation_fir_orig
      end

      def interpolation_fir= coef
        # expand interpolation filter for matrix by padding with 0s
        remainder = coef.size % @interpolation_size
        if remainder > 0
          coef = coef.to_a + [0]*(@interpolation_size-remainder)
        end
        if @interpolation_fir_orig
          raise "can't grow filter" if coef.size > @interpolation_fir_size
        else
          @interpolation_fir_pos = 0
          @interpolation_fir_size = coef.size / @interpolation_size
          @interpolation_buf_f = NArray.sfloat @interpolation_fir_size
          @interpolation_buf_c = NArray.scomplex @interpolation_fir_size
        end
        @interpolation_fir_orig = coef
        setup_interpolation
      end
      
      def decimation_mix= mix
        @decimation_mix = mix
        @decimation_fir_pos = 0 # sync to mixer
        @decimation_phase, @decimation_inc = 
          new_mixer @decimation_mix, @decimation_size
        setup_decimation if @decimation_fir_orig
      end
      alias :mix= :decimation_mix=

      def decimation_fir= coef
        if @decimation_fir_orig
          raise "can't grow filter" if coef.size > @decimation_fir_size
        else
          @decimation_fir_pos = 0
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
      alias :fir= :decimation_fir=
      
      private
      
      def setup
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
        staging = double_filter premix_filter @interpolation_fir_orig, @interpolation_mix
        # interpolation is shaped to avoid 0*0 ops
        ranks = staging.size / @interpolation_size
        pivot = staging.reshape(@interpolation_size, ranks)
        staging.reshape!(ranks, @interpolation_size)
        @interpolation_size.times {|rank| staging[true,rank] = pivot[rank,true]}
        @interpolation_fir_coef = preslice_filter staging
      end

      def setup_decimation
        coef = premix_filter @decimation_fir_orig, @decimation_mix
        @decimation_fir_coef = preslice_filter double_filter coef
      end
      
      # There's no obviously easy way to get NArray to
      # mul_accum on a slice without making a temporary
      # object.  So we make them all and store them in a
      # regular Ruby array.
      def preslice_filter filter
        slices = []
        steps = filter.shape[0] / 2
        steps.times do |i|
          f_start = steps-i
          f_end = -1-i
          if filter.rank == 2
            slices << filter[f_start..f_end, true]
          else
            slices << filter[f_start..f_end]
          end
        end
        slices
      end
      
      # We build filters with two copies of data so a
      # circular buffer can mul_accum on a slice.
      def double_filter coef
        coef = coef.to_a
        if Complex === coef[0]
          new_coef = NArray.scomplex coef.size * 2
        else
          new_coef = NArray.sfloat coef.size * 2
        end
        # reverse into position
        new_coef[coef.size-1..0] = coef
        new_coef[-1..coef.size] = coef
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
        size ||= 1
        return [Complex(1.0,1.0)/Complex(1.0,1.0).abs,
                Math.exp(Complex(0, PI2 * mix * size))]
      end

    end

    module Fir
      include SetupFir
      module Complex
        def call data
          out = NArray.scomplex data.size
          data.size.times do |i|
            @decimation_fir_pos = @decimation_fir_size if @decimation_fir_pos == 0
            @decimation_fir_pos -= 1
            @decimation_buf[@decimation_fir_pos] = data[i..i]
            out[i] = @decimation_fir_coef[@decimation_fir_pos].mul_accum @decimation_buf, 0
          end
          yield out
        end
      end
    end
    
    module Mix
      include SetupFir
      def call data, &block
        call! data.dup, &block
      end
      def call! data
        @decimation_phase /= @decimation_phase.abs
        yield(data.collect! do |v|
          v * @decimation_phase *= @decimation_inc
        end)
      end
    end

    module MixFir
      include SetupFir
      def call data, &block
        call! data.dup, &block
      end
      def call! data
        @decimation_phase /= @decimation_phase.abs
        data.collect! do |value|
          @decimation_buf[@decimation_fir_pos] = value
          @decimation_fir_pos += 1
          @decimation_fir_pos = 0 if @decimation_fir_pos == @decimation_fir_size
          @decimation_phase *= @decimation_inc
          value = @decimation_fir_coef[@decimation_fir_pos].mul_accum @decimation_buf, 0
          value[0] * @decimation_phase
        end
        yield data
      end
    end

    module MixDecimateFir
      include SetupFir
      def call data
        data_size = data.size
        @decimation_phase /= @decimation_phase.abs
        out_size = data_size / @decimation_size
        out_size += 1 if @decimation_size - @decimation_pos <= data_size % @decimation_size
        out = NArray.scomplex out_size
        out_count = 0
        i = 0
        while i < data_size
          want = (@decimation_size - @decimation_pos).round
          remaining = data_size - i
          space = @decimation_fir_size - @decimation_fir_pos
          actual = [want,remaining,space].min
          new_fir_pos = @decimation_fir_pos + actual
          @decimation_buf[@decimation_fir_pos...new_fir_pos] = data[i...i+actual]
          @decimation_fir_pos = new_fir_pos
          @decimation_fir_pos = 0 if @decimation_fir_pos == @decimation_fir_size
          @decimation_pos += actual
          if @decimation_pos >= @decimation_size
            @decimation_pos -= @decimation_size
            j = @decimation_fir_coef[@decimation_fir_pos].mul_accum @decimation_buf, 0
            out[out_count] = j * @decimation_phase *= @decimation_inc
            out_count += 1
          end
          i += actual
        end
        yield out unless out.empty?
      end
    end

    module InterpolateFir
      include SetupFir
      module Float
        def call data
          out = NArray.sfloat @interpolation_size, data.size
          index = 0
          data.each do |value|
            @interpolation_buf_f[@interpolation_fir_pos] = value
            @interpolation_fir_pos += 1
            @interpolation_fir_pos = 0 if @interpolation_fir_pos == @interpolation_fir_size
            iq = @interpolation_fir_coef[@interpolation_fir_pos].mul_accum @interpolation_buf_f, 0
            out[true,index] = iq.reshape!(iq.size).mul!(@interpolation_size)
            index += 1
          end
          yield out.reshape!(out.size)
        end
      end
    end

    module MixInterpolateFir
      include SetupFir
      def call data
        @interpolation_phase /= @interpolation_phase.abs
        out = NArray.scomplex @interpolation_size, data.size
        index = 0
        data.each do |value|
          @interpolation_buf_c[@interpolation_fir_pos] = value
          @interpolation_fir_pos += 1
          @interpolation_fir_pos = 0 if @interpolation_fir_pos == @interpolation_fir_size
          iq = @interpolation_fir_coef[@interpolation_fir_pos].mul_accum @interpolation_buf_c, 0
          @interpolation_phase *= @interpolation_inc
          out[true,index] = iq.reshape!(iq.size).mul!(@interpolation_phase * @interpolation_size)
          index += 1
        end
        yield out.reshape!(out.size)
      end
    end
    
  end
end