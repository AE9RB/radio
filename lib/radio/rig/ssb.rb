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
        if output and !iq?
          raise 'requires i/q signal'
        end
        old_af_thread = false
        @ssb_semaphore.synchronize do
          deregister @af_queue if @af_queue
          @af_queue = nil
          old_rate = 0
          if @af
            @af.stop
            old_af_thread = @af_thread
            old_af_thread.kill if old_af_thread
          end
          if @af = output
            @bfo_filter = bfo_mixer
            @af_filter = af_generate_filter
          
            #TODO need a nicer pattern to force JIT compile
            @bfo_filter.call(NArray.scomplex(1)) {}
            @af_filter.call(NArray.sfloat(1)) {}
          
            register @af_queue = Queue.new
            @af_thread = Thread.new &method(:af_thread)
          end
        end
        old_af_thread.join if old_af_thread
      end
      
      def tune= freq
        @ssb_semaphore.synchronize do
          return unless @af
          @bfo_filter.decimation_mix = freq / rate
        end
      end
      
      private
      
      def af_thread
        begin
          loop do
            in_data = @af_queue.pop
            @ssb_semaphore.synchronize do
              if @af_filter and @af
                @bfo_filter.call(in_data) do |iq|
                  # pcm = (iq.real + iq.imag) * 20
                  pcm = (iq.real - iq.imag) * 30
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
        bands[2] = 3000.0 / rate
        bands[3] = 0.5
        taps = kaiser_estimate passband:0.35, stopband:0.35, transition:bands[2]-bands[1]
        fir1 = remez numtaps: taps, type: :bandpass,
          bands: bands, desired: [1,1,0,0], weights: [1,50]
        fir2 = remez numtaps: taps, type: :hilbert,
          bands: bands, desired: [1,1,0,0], weights: [1,50]
        decimate = rate.to_f / 6000
        unless decimate == decimate.floor
          raise "unable to filter #{rate} to 6000"
        end
        fir = NArray.scomplex fir1.size
        fir[true] = fir1.to_a
        fir.imag = fir2.to_a
        Filter.new fir:fir, decimate:decimate, mix:0
      end
      
      
      def af_generate_filter
        return nil unless @af
        bands = [0,nil,nil,0.5]
        bands[1] = 2800.0 / @af.rate
        bands[2] = 3200.0 / @af.rate
        taps = kaiser_estimate passband:0.1, stopband:0.1, transition:bands[2]-bands[1]
        fir = remez numtaps: taps, type: :bandpass,
          bands: bands, desired: [1,1,0,0], weights: [10,1]
        interpolate = @af.rate.to_f / 6000
        unless interpolate == interpolate.floor
          raise "unable to filter 6000 to #{@af.rate}"
        end
        filter = Filter.new fir:fir, interpolate:interpolate
        filter
      end
      
      
    end

  end
end
  
