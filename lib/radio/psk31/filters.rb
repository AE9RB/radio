class Radio
  
  class PSK31
    
    # An instance of Filters handles everything from 48kHz to 500Hz.
    # PSK31/PSK63/PSK125 emit at 500Hz/1000Hz/2000Hz respectively.
    
    class Filters
      
      attr_accessor :frequency
      attr_accessor :clock # 8000.0 +/-
      attr_accessor :phase_inc
      attr_accessor :speed # 31 | 63 | 125
      
      # Format of the input data stream is specified in the same
      # format as String#unpack.  Here are some examples:
      #   'C' 8-bit unsigned mono
      #   'xxv' Little-endian 16-bit right channel
      # Not everything is supported outside this native Ruby implementation.
      # The following are guaranteed to be in a C or Java implementation.
      #   x - ignores a byte (in an unused channel)
      #   C/c - Unsigned/signed bytes
      #   n/v - Unsigned 16-bit words in big/little endian format
      
      # You must supply at least one of the dec16, dec8, or dec4 filters and
      # it must be appropriate for the speed you desire.  The dec4 filter can
      # be used for all speeds, dec8 only for PSK63, and dec16 only for PSK31.

      def initialize sample_rate, format, frequency, filters
        @do_dec6 = case sample_rate
        when 8000 then false
        when 48000 then true
        else raise 'only 8000 and 48000 Hz sample rates are supported'
        end
        @format = format
        @sample_size = [0].pack(format).size
        case ("\x80"*16).unpack(format)[0]
        when 128
          @max = 128
          @offset = -128
        when -128
          @max = 128
          @offset = 0
        when 32768 + 128
          @max = 32768
          @offset = -32768
        when -32768 + 128
          @max = 32768
          @offset = 0
        else
          raise 'unable to interpret format'
        end
        @frequency = frequency
        @clock = 8000.0
        @phase = 0.0
        @speed = 31
        @pulse = 0
        if filters[:dec6]
          @dec6_coef = NArray.to_na filters[:dec6].reverse*2
          @dec6_data = NArray.float filters[:dec6].size
          @dec6_pos = 0
          @dec6_pulse = 6
        elsif @do_dec6
          raise 'no 48000 Hz filter found'
        end
        if filters[:dec16]
          @dec16_coef = NArray.to_na filters[:dec16].reverse*2
          @dec16_sin = NArray.float filters[:dec16].size
          @dec16_cos = NArray.float filters[:dec16].size
          @dec16_pos = 0
        else
          @dec16_coef = nil
        end
        if filters[:dec8]
          @dec8_coef = NArray.to_na filters[:dec8].reverse*2
          @dec8_sin = NArray.float filters[:dec8].size
          @dec8_cos = NArray.float filters[:dec8].size
          @dec8_pos = 0
        else
          @dec8_coef = nil
        end
        if filters[:dec4]
          @dec4_coef = NArray.to_na filters[:dec4].reverse*2
          @dec4a_sin = NArray.float filters[:dec4].size
          @dec4a_cos = NArray.float filters[:dec4].size
          @dec4a_pos = 0
          @dec4b_sin = NArray.float filters[:dec4].size
          @dec4b_cos = NArray.float filters[:dec4].size
          @dec4b_pos = 0
        else
          @dec4_coef = nil
        end
        @bit_coef = NArray.to_na filters[:bit].reverse*2
        @bit_sin = NArray.float filters[:bit].size
        @bit_cos = NArray.float filters[:bit].size
        @bit_pos = 0
        recalc_phase_inc
      end
      
      def reset
        if @dec6_coef
          @dec6_data.fill 0.0
        end
        if @dec16_coef
          @dec16_sin_data.fill 0.0 
          @dec16_cos_data.fill 0.0
        end
        if @dec8_coef
          @dec8_sin_data.fill 0.0
          @dec8_cos_data.fill 0.0
        end
        if @dec4_coef
          @dec4a_sin.fill 0.0
          @dec4a_cos.fill 0.0
          @dec4b_sin.fill 0.0
          @dec4b_cos.fill 0.0
        end
        @bit_sin.fill 0.0
        @bit_cos.fill 0.0
      end
      
      def recalc_phase_inc
        @phase_inc = PI2 * @frequency / @clock
      end
      
      def call sample_data
        raise 'alignment error' unless sample_data.size % @sample_size == 0
        sample_data.force_encoding('binary') # Ensure slice is fast like Ruby 1.9.3 byteslice
        mod16_8 = @speed == 63 ? 8 : 16
        pos = 0
        while pos < sample_data.size
          pos += @sample_size
          sample = sample_data.slice(pos,@sample_size).unpack(@format)[0] || 0
          sample = (sample + @offset).to_f / @max
          if @do_dec6
            @dec6_pos = @dec6_data.size if @dec6_pos == 0
            @dec6_pos -= 1
            @dec6_data[@dec6_pos] = sample
            @dec6_pulse -= 1
            next unless @dec6_pulse == 0
            @dec6_pulse = 6
            sample = @dec6_data.fir(@dec6_coef, @dec6_pos)
          end
          @phase += @phase_inc
          @phase -= PI2 if @phase > PI2
          if @dec16_coef and @speed == 31
            @dec16_pos = @dec16_sin.size if @dec16_pos == 0
            @dec16_pos -= 1
            @dec16_sin[@dec16_pos] = sample * Math.sin(@phase)
            @dec16_cos[@dec16_pos] = sample * Math.cos(@phase)
            next unless ((@pulse = @pulse + 1 & 0xFF) % 16) == 0
            ival = @dec16_sin.fir(@dec16_coef, @dec16_pos)
            qval = @dec16_cos.fir(@dec16_coef, @dec16_pos)
          elsif @dec8_coef and @speed == 63
            @dec8_pos = @dec8_sin.size if @dec8_pos == 0
            @dec8_pos -= 1
            @dec8_sin[@dec8_pos] = sample * Math.sin(@phase)
            @dec8_cos[@dec8_pos] = sample * Math.cos(@phase)
            next unless ((@pulse = @pulse + 1 & 0xFF) % 8) == 0
            ival = @dec8_sin.fir(@dec8_coef, @dec8_pos)
            qval = @dec8_cos.fir(@dec8_coef, @dec8_pos)
          elsif @dec4_coef
            @dec4a_pos = @dec4a_sin.size if @dec4a_pos == 0
            @dec4a_pos -= 1
            @dec4a_sin[@dec4a_pos] = sample * Math.sin(@phase)
            @dec4a_cos[@dec4a_pos] = sample * Math.cos(@phase)
            next unless ((@pulse = @pulse + 1 & 0xFF) % 4) == 0
            @dec4b_pos = @dec4b_sin.size if @dec4b_pos == 0
            @dec4b_pos -= 1
            ival = @dec4b_sin[@dec4b_pos] = @dec4a_sin.fir(@dec4_coef, @dec4a_pos)
            qval = @dec4b_cos[@dec4b_pos] = @dec4a_cos.fir(@dec4_coef, @dec4a_pos)
            next unless @speed == 125 or (@pulse % mod16_8 == 0)
            unless @speed == 125
              ival = @dec4b_sin.fir(@dec4_coef, @dec4b_pos)
              qval = @dec4b_cos.fir(@dec4_coef, @dec4b_pos)
            end
          else
            raise 'no suitable filter found'
          end
          @bit_pos = @bit_sin.size if @bit_pos == 0
          @bit_pos -= 1
          @bit_sin[@bit_pos] = ival
          @bit_cos[@bit_pos] = qval
          yield @bit_sin.fir(@bit_coef, @bit_pos), @bit_cos.fir(@bit_coef, @bit_pos)
        end
      end
      
      # NArray can easily double filter performance
      begin
        require 'narray'
        class ::NArray
          def fir filter, pos
            (self * filter[size-pos..-1-pos]).sum
          end
        end
      rescue LoadError => e
        # Pure Ruby fake NArray
        class NArray < Array
          def self.float arg
            new arg, 0.0
          end
          def self.to_na arg
            new(arg).freeze
          end
          def fir filter, pos
            acc = 0.0
            index = size - pos
            each do |val|
              acc += val * filter[index]
              index += 1
            end
            acc
          end
        end
      end
      
    end
  end
end

