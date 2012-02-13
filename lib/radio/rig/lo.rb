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
    module LO
  
      def initialize
        @lo = Controls::Null.new
        super
      end
      
      # Accepts an instance of any LO control to use.
      # Float for the frequency in MHz (sub-Hz ok).
      # Integer for the frequency in Hz.
      def lo= freq_or_control
        @semaphore.synchronize do
          if Numeric === freq_or_control
            @lo.lo = if freq_or_control.integer?
              freq_or_control.to_f / 1000000
            else
              freq_or_control
            end
          else
            @lo.stop if @lo
            @lo = freq_or_control
          end
        end
      end

      # Returns a float of the LO frequency in MHz.
      # This will read from the actual device for the case of an
      # operator adjusting outside this application, such as with
      # the main dial of a stand-alone radio.
      def lo
        @semaphore.synchronize do
          @lo.lo
        end
      end
    
    end
  end
end


