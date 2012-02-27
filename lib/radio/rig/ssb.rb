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
        @ssb_semaphore = Mutex.new
        super
      end
      
      def af= output
        old_af_thread = false
        @ssb_semaphore.synchronize do
          deregister @af_queue if @af_queue
          old_rate = 0
          if @af
            old_rate = @af.rate
            @af.stop
            old_af_thread = @af_thread
            old_af_thread.kill
          end
          @af = output
          @bfo_filter = bfo_mixer
          @af_filter = af_generate_filter
          register @af_queue = Queue.new
          @af_thread = Thread.new &method(:af_thread)
        end
        old_af_thread.join if old_af_thread
      end
      
      private
      
      def af_thread
        begin
          loop do
            in_data = @af_queue.pop
            @ssb_semaphore.synchronize do
              if @af_filter and @af
                @bfo_filter.call(in_data) do |iq|
                  pcm = (iq.real + iq.imag) * 30
                  # pcm = (iq.real - iq.imag) * 30
                  @af_filter.call(pcm) do |data| 
                    @af.out data
                  end
                end
              end
            end
          end
        rescue Exception => e
          p "ERROR #{e.message}: #{e.backtrace.first}" #TODO logger
          raise e
        end
      end
      

      def bfo_mixer
        rate = self.rate
        bands = []
        bands[0] = 0.0 / rate
        bands[1] = 2800.0 / rate
        bands[2] = 3100.0 / rate
        bands[3] = 0.5
        taps = kaiser_estimate passband:0.3, stopband:0.3, transition:bands[2]-bands[1]
        # p taps
        fir1 = remez numtaps: taps, type: :bandpass,
          bands: bands, desired: [1,1,0,0], weights: [1,50]
        fir2 = remez numtaps: taps, type: :hilbert,
          bands: bands, desired: [1,1,0,0], weights: [1,50]
        
        # ssb.rb
        tune = 5500.0  #LSB
        # tune = 36900.0  #LSB
        
        decimate = rate / 6000
        mix = tune / rate

        fir = NArray.scomplex fir1.size
        fir[true] = fir1.to_a
        fir.imag = fir2.to_a

        Filter.new fir:fir, decimate:decimate, mix:mix
      end
      
      
      def af_generate_filter
        return nil unless @af
        bands = [0,nil,nil,0.5]
        bands[1] = 2800.0 / @af.rate
        bands[2] = 3800.0 / @af.rate
        taps = kaiser_estimate passband:0.01, stopband:0.1, transition:bands[2]-bands[1]
        fir = remez numtaps: taps, type: :bandpass,
          bands: bands, desired: [1,1,0,0], weights: [10,1]
        interpolate = @af.rate.to_f / 6000 #######
        unless interpolate == interpolate.floor and interpolate > 0
          raise "unable to convert #{rate} to #{@af.rate}"
        end
        filter = Filter.new fir:fir, interpolate:interpolate
        #TODO need a nicer pattern to force JIT compile
        filter.call(NArray.sfloat(1)) {}
        filter
      end
      
      
    end

  end
end
  
