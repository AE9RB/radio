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
    
    module Rx
      
      def initialize
        @rx = @rx_thread = nil
        super
      end
      
      def rx= input
        old_rx_thread = false
        @semaphore.synchronize do
          if @rx
            @rx.stop
            old_rx_thread = @rx_thread
            old_rx_thread.kill
          end
          if @rx = input
            @rx_thread = Thread.new &method(:rx_thread)
          end
        end
        old_rx_thread.join if old_rx_thread
      end
  
      private
    
      # DSP under an OS requires chunked and streaming processing
      # as opposed to handling every sample as it arrives.
      # We want to work with powers of two but sample rates
      # are multiples of 8000. Let's use a lag of 32ms or 31.25 baud.
      def rx_thread
        begin
          qty_samples = @rx.rate / 125 * 4
          loop do
            distribute_to_listeners @rx.in qty_samples
          end
        rescue Exception => e
          p "ERROR #{e.message}: #{e.backtrace.first}" #TODO logger
          # This will be picked up by next call to rx=
          raise e
        end
      end
    
    end
  
  end
end


