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
  class Filter

    module FloatAgc
      
      def setup data
        @gain = @options[:agc]
        if Numeric === @gain
          @gain = @gain.to_f
        else
          @gain = 20.0
        end
        @min = 0.0001
        @max = 0.0
        @attack = 0.05
        @decay = 0.01
        @reference = 0.05
        super
      end
      
      def call data
        yield(data.collect do |v|
          out = @gain * v
          abs_delta = out.abs - @reference
          if abs_delta.abs > @gain
            rate = @attack
            out = -1.0 if out < -1.0
            out = 1.0 if out > 1.0
          else
            rate = @decay
            if out < -1.0
              out = -1.0
              rate *= 3
            end
            if out > 1.0
              out = 1.0
              rate *= 3
            end
          end
          @gain -= abs_delta * rate
          out
        end)
      end
      
    end
    
  end
end