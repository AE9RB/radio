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
          @af_filter = af_generate_filter unless @af and old_rate == @af.rate
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
                @af_filter.call(in_data) {|data| @af.out data}
              end
            end
          end
        rescue Exception => e
          p "ERROR #{e.message}: #{e.backtrace.first}" #TODO logger
          raise e
        end
      end
      
      def af_generate_filter
        return nil unless @af
        bands = [0,nil,nil,0.5]
        bands[1] = 3000.0 / @af.rate
        bands[2] = 3800.0 / @af.rate
        taps = kaiser_estimate passband:0.05, stopband:0.05, transition:bands[2]-bands[1]
        fir = remez numtaps: taps, type: :bandpass,
          bands: bands, desired: [1,1,0,0], weights: [50,1]
        interpolate = @af.rate.to_f / self.rate
        unless interpolate == interpolate.floor and interpolate > 0
          raise "unable to convert #{rate} to #{@af.rate}"
        end
        filter = Filter.new fir:fir, interpolate:interpolate
        #TODO need a nicer pattern to force JIT compile
        filter.call(self.iq? ? NArray.scomplex(1) : NArray.sfloat(1)) {}
        filter
      end
      
    end

  end
end
  
