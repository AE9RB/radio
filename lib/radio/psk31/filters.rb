class Radio
  
  class PSK31
    
    # An instance of Filters handles everything from 48kHz to 500Hz.
    # PSK31/PSK63/PSK125 emit at 500Hz/1000Hz/2000Hz respectively.
    
    class Filters
      
      attr_accessor :frequency
      attr_accessor :phase_inc
      attr_accessor :speed # 31 | 63 | 125
      
      # dec16 is for testing a single decimation filter vs the standard dual

      def initialize frequency, dec_coef, bit_coef, dec16_coef=nil
        @frequency = frequency
        @phase = 0.0
        @phase_inc = 0.0
        @speed = 31
        @pulse = 0
        if dec16_coef
          @dec16_coef = NArray.to_na dec16_coef.reverse*2
          @dec16_sin = NArray.float dec16_coef.size
          @dec16_cos = NArray.float dec16_coef.size
          @dec16_pos = 0
        else
          @dec16_coef = nil
        end
        @dec_coef = NArray.to_na dec_coef.reverse*2
        @dec1_sin = NArray.float dec_coef.size
        @dec1_cos = NArray.float dec_coef.size
        @dec1_pos = 0
        @dec2_sin = NArray.float dec_coef.size
        @dec2_cos = NArray.float dec_coef.size
        @dec2_pos = 0
        @bit_coef = NArray.to_na bit_coef.reverse*2
        @bit_sin = NArray.float bit_coef.size
        @bit_cos = NArray.float bit_coef.size
        @bit_pos = 0
      end
      
      def reset
        if @dec16_coef
          @dec16_sin_data.fill 0.0 
          @dec16_cos_data.fill 0.0
        end
        @dec1_sin.fill 0.0
        @dec1_cos.fill 0.0
        @dec2_sin.fill 0.0
        @dec2_cos.fill 0.0
        @bit_sin.fill 0.0
        @bit_cos.fill 0.0
      end
      
      def call sample_data
        mod16_8 = @speed == 63 ? 8 : 16
        sample_data.each do |sample|
          @phase += @phase_inc
          @phase -= PI2 if @phase >= PI2
          if @dec16_coef and @speed == 31
            @dec16_pos = @dec16_sin.size if @dec16_pos == 0
            @dec16_pos -= 1
            @dec16_sin[@dec16_pos] = sample * Math.sin(@phase)
            @dec16_cos[@dec16_pos] = sample * Math.cos(@phase)
            next unless ((@pulse = @pulse + 1 & 0xFF) % 16) == 0
            sin_val = @dec16_sin.fir(@dec16_coef, @dec16_pos)
            cos_val = @dec16_cos.fir(@dec16_coef, @dec16_pos)
          else
            @dec1_pos = @dec1_sin.size if @dec1_pos == 0
            @dec1_pos -= 1
            @dec1_sin[@dec1_pos] = sample * Math.sin(@phase)
            @dec1_cos[@dec1_pos] = sample * Math.cos(@phase)
            next unless ((@pulse = @pulse + 1 & 0xFF) % 4) == 0
            sin_val = @dec2_sin[@dec2_pos] = @dec1_sin.fir(@dec_coef, @dec1_pos)
            cos_val = @dec2_cos[@dec2_pos] = @dec1_cos.fir(@dec_coef, @dec1_pos)
            unless @speed == 125
              @dec2_pos = @dec2_sin.size if @dec2_pos == 0
              @dec2_pos -= 1
              @dec2_sin[@dec2_pos] = sin_val
              @dec2_cos[@dec2_pos] = cos_val
              next unless @pulse % mod16_8 == 0
            end
            unless @speed == 125
              sin_val = @dec2_sin.fir(@dec_coef, @dec2_pos)
              cos_val = @dec2_cos.fir(@dec_coef, @dec2_pos)
            end
          end
          @bit_pos = @bit_sin.size if @bit_pos == 0
          @bit_pos -= 1
          @bit_sin[@bit_pos] = sin_val
          @bit_cos[@bit_pos] = cos_val
          yield @bit_sin.fir(@bit_coef, @bit_pos), @bit_cos.fir(@bit_coef, @bit_pos)
        end
      end
      
    end
  end
end

