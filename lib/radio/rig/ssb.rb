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
            @agc = Filter.new :agc => true
            @iq = Filter.new :iq => true
            @mix = mixmix
          
            #TODO need a nicer pattern to force JIT compile
            @bfo_filter.call(NArray.scomplex(1)) {}
            @af_filter.call(NArray.sfloat(1)) {}
            @agc.call(NArray.sfloat(1)) {}
            @iq.call(NArray.scomplex(1)) {}
          
            register @af_queue = Queue.new
            @af_thread = Thread.new &method(:af_thread)
          end
        end
        old_af_thread.join if old_af_thread
      end
      
      def tune= freq
        @ssb_semaphore.synchronize do
          @freq = freq
          set_mixers
        end
      end
      
      def set_lsb
        @ssb_semaphore.synchronize do
          if @bfo_filter
            @ssb_mode = :lsb
            @bfo_filter.decimation_fir = @lsb_coef 
            set_mixers
          end
        end
      end

      def set_usb
        @ssb_semaphore.synchronize do
          if @bfo_filter
            @ssb_mode = :usb
            @bfo_filter.decimation_fir = @usb_coef
            set_mixers
          end
        end
      end
      
      private
      
      def set_mixers
        return unless @af and @bfo_filter
        freq = @freq.to_f 
        if @ssb_mode == :usb
          @bfo_filter.decimation_mix = (freq-1300) / rate
          @mix.mix = +1300.0 / 6000
        else
          @bfo_filter.decimation_mix = (freq+1300) / rate
          @mix.mix = -1300.0 / 6000
        end
      end
      
      def af_thread
        begin
          loop do
            in_data = @af_queue.pop
            @ssb_semaphore.synchronize do
              if @af_filter and @af
                @bfo_filter.call(in_data) do |iq|
                  
                  @mix.call!(iq) do |iq|
                  @iq.call!(iq) do |iq|
                  
                    @agc.call(iq.real + iq.imag) do |pcm|
                      @af_filter.call(pcm) do |data| 
                        @af.out data
                      end
                    end
                  end
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
      
      def mixmix
        rate = 6000
        bands = []
        bands[0] = 0.0 / rate
        bands[1] = 2400.0 / rate
        bands[2] = 2600.0 / rate
        bands[3] = 0.5
        taps = kaiser_estimate passband:0.01, stopband:0.01, transition:bands[2]-bands[1]
        fir = firpm numtaps: taps, type: :bandpass,
          bands: bands, desired: [1,1,0,0], weights: [1,1000]
        Filter.new :mix => (1300.0 / rate), :fir => fir
      end

      def bfo_mixer
        rate = self.rate.to_f
        decimate = rate / 6000
        unless decimate == decimate.floor
          raise "unable to filter #{rate} to 6000"
        end
        bands = []
        bands[0] = 0.0 / rate
        bands[1] = 1200.0 / rate
        bands[2] = 1500.0 / rate
        bands[3] = 0.5
        taps = kaiser_estimate passband:0.1, stopband:0.1, transition:bands[2]-bands[1]
        p taps
        taps = 271
        p taps
        fir1 = firpm numtaps: taps, type: :bandpass,
          bands: bands, desired: [1,1,0,0], weights: [1,10000]
        fir2 = firpm numtaps: taps, type: :hilbert,
          bands: bands, desired: [1,1,0,0], weights: [1,10000]
        @usb_coef = NArray.scomplex fir1.size
        @usb_coef[true] = fir1.to_a
        @usb_coef.imag = fir2.to_a
        @lsb_coef = @usb_coef.conj
        @ssb_mode = :usb
        Filter.new fir:@usb_coef, decimate:decimate, mix:0
      end
      
      def af_generate_filter
        return nil unless @af
        bands = [0,nil,nil,0.5]
        bands[1] = 2400.0 / @af.rate
        bands[2] = 3000.0 / @af.rate
        taps = kaiser_estimate passband:0.01, stopband:0.01, transition:bands[2]-bands[1]
        fir = firpm numtaps: taps, type: :bandpass,
          bands: bands, desired: [1,1,0,0], weights: [1,1000]
        interpolate = @af.rate.to_f / 6000
        unless interpolate == interpolate.floor
          raise "unable to filter 6000 to #{@af.rate}"
        end
        Filter.new fir:fir, interpolate:interpolate
      end
      
      
    end

  end
end
  
