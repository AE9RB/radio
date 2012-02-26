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
  
  class Rig
    
    module SSB
      
      def initialize
        @af = @af_thread = nil
        register @af_queue = Queue.new
        # start a null thread to consume queue
        self.af = nil 
        super
      end
      
      def af= output
        old_af_thread = false
        source_rate = self.rate
        @semaphore.synchronize do
          old_rate = 0
          if @af
            old_rate = @af.rate
            @af.stop
            old_af_thread = @af_thread
            old_af_thread.kill
          end
          @af = output
          @af_filter = af_generate_filter(source_rate) unless @af and old_rate == @af.rate
          @af_thread = Thread.new &method(:af_thread)
        end
        old_af_thread.join if old_af_thread
      end
      
      private
      
      def af_thread
        begin
          loop do
            in_data = @af_queue.pop
            @semaphore.synchronize do
              if @af_filter and @af
                @af_filter.call(in_data) {|data| @af.out data}
              end
            end
          end
        rescue Exception => e
          p "ERROR #{e.message}: #{e.backtrace.first}" #TODO logger
          raise e
        end
      end
      
      def af_generate_filter(source_rate)
        return nil unless @af
        bands = [0,0,0,0.5]
        bands[1] = 3000.0 / @af.rate
        bands[2] = 3800.0 / @af.rate
        taps = kaiser_estimate :odd, 0.05, 0.05, bands[2].to_f-bands[1]
        fir = Remez.new numtaps: taps, type: :bandpass,
          bands: bands, desired: [1,1,0,0], weights: [1,100]
        interpolate = @af.rate.to_f / source_rate
        unless interpolate == interpolate.floor and interpolate > 0
          raise "unable to convert #{rate} to #{@af.rate}"
        end
        Filter.new fir:fir, interpolate:interpolate
      end
      
      #TODO make a Util module and include remez with this
      def kaiser_estimate type, passband_ripple, stopband_ripple, transition_width
        numer = -20.0 * Math.log10(passband_ripple.to_f*stopband_ripple) - 13
        denum = 14.6 * transition_width
        taps = (numer/denum).round
        taps +=1 if type == :odd and taps.even?
        taps +=1 if type == :even and taps.odd?
        taps
      end
      
    end

  end
end
  
