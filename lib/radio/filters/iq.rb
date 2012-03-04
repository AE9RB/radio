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

    # this is the IQ detection idea from the sdr# project
    #TODO need a new ruby fftw3 interface for performance
    module ComplexIq
      
      def setup data
        @bins = 1024
        @every = 3
        @count = 0
        @guesses = 10
        @dc_rate = 0.00001
        @iq_rate = 0.0001
        @biasI = 0.0
        @biasQ = 0.0
        @gain = 1.0
        @phase = 0.0
        @fft = NArray.scomplex @bins
        @fft_pos = 0
      end
      
      def call data, &block
        call! data.dup, &block
      end

      def call! data
        remove_dc_bias! data
        estimate! data
        adjust! data, @phase, @gain
        yield data
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
      
      #TODO DRY this with FIR hihi
      def estimate! data
        i = 0
        data_size = data.size
        while i < data_size
          remaining = data_size - i
          space = @bins - @fft_pos
          actual = [remaining,space].min
          new_fft_pos = @fft_pos + actual
          if actual == 1
            @fft[@fft_pos] = data[i]
          else
            @fft[@fft_pos...new_fft_pos] = data[i...i+actual]
          end
          @fft_pos = new_fft_pos
          if @fft_pos == @bins
            @fft_pos = 0
            @count += 1
            if @count == @every
              @count = 0
              est_pt2
            end
          end
          i += actual
        end
      end
      
      def utility spectrum
        result = 0.0
        length = @bins.size
        halfLength = length / 2
        start = (0.10 * halfLength).round
        finish = (0.90 * halfLength).round
        (start..finish).each do |i|
          result += (spectrum[i] - spectrum[length - 2 - i]).abs
        end
        result
      end
      
      def rand_direction
        rand*2-1
      end
      
      def est_pt2
        fft = @fft.dup
        adjust! fft, @phase, @gain
        util = utility FFTW3::fft(fft)
        @guesses.times do
          phaseIncrement = @iq_rate * rand_direction
          gainIncrement = @iq_rate * rand_direction
          fft = @fft.dup
          adjust! fft, @phase + phaseIncrement, @gain + gainIncrement
          u = utility FFTW3::fft(fft)
          if u > util
            util = u
            @gain += gainIncrement
            @phase += phaseIncrement
          end
        end
      end
      
    end
  
  end
end

