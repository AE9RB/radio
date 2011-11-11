class Radio
  
  class PSK31
    
    class Rx

      def initialize sample_rate, format, frequency
        @filter = Filters.new sample_rate, format, frequency, 
          :dec6 => FIR_DEC6,
          :dec16 => FIR_DEC16,
          :dec4 => FIR_DEC4,
          :bit => FIR_BIT
        @bit_detect = BitDetect.new
        @decoder = Decoder.new
      end
      
      def call sample_data
        decoded = ''
        @filter.call sample_data do |i, q|
          @bit_detect.call i, q do
            @decoder.call i, q do |symbol|
              decoded += symbol
            end
          end
        end
        decoded
      end
      
      def frequency= frequency
        if frequency != @filter.frequency
          @filter.frequency = frequency
          @filter.recalc_phase_inc
          reset
        end
      end
      
      # To compensate for bad clock in A-D conversion
      def adjust_sample_clock ppm
        @filter.clock = 8000.0 * ppm / 1000000 + 8000
        @filter.recalc_phase_inc
      end
      
      def reset
        @filter.reset
        @bit_detect.reset
        @decoder.reset
      end
      
    end
    
  end
end
