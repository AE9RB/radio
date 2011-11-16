class Radio
  
  class PSK31
    
    class Rx

      def initialize format, frequency, ppm_adjust=0
        @filter = Filters.new format, frequency, FIR_DEC, FIR_BIT
        @bit_detect = BitDetect.new
        @decoder = Decoder.new
        adjust_clock ppm_adjust
      end
      
      # Ensure slice is fast when possible
      # sample_data.force_encoding('binary') 
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
        unless frequency == @filter.frequency
          @filter.frequency = frequency
          recalc_phase_inc
          reset
        end
      end
      
      # To compensate for bad clock in A-D conversion
      def adjust_clock ppm
        @clock = 8000.0 * ppm / 1000000 + 8000
        recalc_phase_inc
      end
      
      def reset
        @filter.reset
        @bit_detect.reset
        @decoder.reset
      end
      
      def recalc_phase_inc
        @filter.phase_inc = PI2 * @filter.frequency / @clock
      end
      
    end
    
  end
end
