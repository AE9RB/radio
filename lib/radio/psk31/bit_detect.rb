class Radio
  
  class PSK31
    
    class BitDetect
      
      AVG_SAMPLES = 50.freeze
      CHANGE_DELAY = 5
      
      def initialize
        @averages = Array.new 21
        reset
      end
      
      def reset
        @averages.fill 0.0
        @phase = 0
        @peak = 0
        @next_peak = 0
        @change_at = 0
      end
      
      def call sample_x, sample_y
        yield if @phase == @peak
        @peak = @next_peak if @phase == @change_at
        energy = sample_x**2 + sample_y**2
        @averages[@phase] = (1.0-1.0/AVG_SAMPLES)*@averages[@phase] + (1.0/AVG_SAMPLES)*energy
        @phase += 1
        if @phase > 15
          @phase = 0
          max = -1e10
          for i in 0...16
            energy = @averages[i]
            if energy > max
              @next_peak = i
              @change_at = (i + CHANGE_DELAY) & 0x0F
              max = energy
            end
          end
        end
      end
      
    end
    
  end
end
