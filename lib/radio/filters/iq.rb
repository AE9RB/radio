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

    module Iq
      
      def setup
        @bins = 512
        @tries = 5
        @dc_rate = 0.00001
        @iq_rate = 0.0001
        @biasI = 0.0
        @biasQ = 0.0
        @gain = 1.0
        @phase = 0.0
        @fft = NArray.scomplex @bins
        @fft_pos = 0
      end
      
      module Complex
        def call data, &block
          call! data.dup, &block
        end

        def call! data
          remove_dc_bias! data
          collect data
          adjust! data, @phase, @gain
          yield data
          analyze # this is slow
        end
      end
      
      # This maintains a buffer of recent data
      # that we can grab for analysis
      def collect data
        i = 0
        data_size = data.size
        while i < data_size
          remaining = data_size - i
          space = @bins - @fft_pos
          actual = [remaining,space].min
          new_fft_pos = @fft_pos + actual
          @fft[@fft_pos...new_fft_pos] = data[i...i+actual]
          @fft_pos = new_fft_pos
          if @fft_pos == @bins
            @fft_pos = 0
            @next_fft = @fft.dup
          end
          i += actual
        end
      end
      
      # Once per call, we will do an FFT to either start a
      # new round of guessing or try again on the current set.
      def analyze
        return unless @cur_fft or @next_fft
        if !@cur_fft_count or @cur_fft_count > @tries
          @cur_fft = @next_fft
          @cur_fft_count = 0
          fft = @cur_fft.dup
          adjust! fft, @phase, @gain
          @cur_fft_best = detect_energies FFTW3::fft(fft)
        else
          @cur_fft_count += 1
          phaseIncrement = @iq_rate * rand_direction
          gainIncrement = @iq_rate * rand_direction
          fft = @cur_fft.dup
          adjust! fft, @phase + phaseIncrement, @gain + gainIncrement
          det = detect_energies FFTW3::fft(fft)
          if det > @cur_fft_best
            @cur_fft_best = det
            @gain += gainIncrement
            @phase += phaseIncrement
          end
        end
      end
      
      
      def remove_dc_bias! data
        data.collect! do |v|
          temp = @biasI * (1 - @dc_rate) + v.real * @dc_rate
          @biasI = temp unless temp.nan?
          real = v.real - @biasQ
          temp = @biasQ * (1 - @dc_rate) + v.imag * @dc_rate
          @biasQ = temp unless temp.nan?
          imag = v.imag - @biasQ
          Complex(real,imag)
        end
      end
      
      def adjust! data, phase, gain
        data.collect! do |v|
          Complex(v.real + phase * v.imag, v.imag * gain)
        end
      end
      
      def detect_energies spectrum
        result = 0.0
        length = @bins.size
        halfLength = length / 2
        start = (0.10 * halfLength).round
        finish = (0.70 * halfLength).round
        spectrum = spectrum.abs
        frag = spectrum[start..finish]
        min = frag.min
        max = frag.max
        threshold = max - (max-min) * 0.7
        (start..finish).each do |i|
          cur = spectrum[length - 1 - i]
          next unless cur > threshold
          diff = cur - spectrum[i]
          next unless diff > 0
          result += diff
        end
        result
      end
      
      # this is the IQ detection idea from the sdr# project
      def rand_direction
        rand*2-1
      end
      
    end
  
  end
end

