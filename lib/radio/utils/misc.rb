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

  PI = Math::PI.freeze
  PI2 = (8.0 * Math.atan(1.0)).freeze
  
  module Utils
    
    def kaiser_estimate options
      ripple = options[:passband].to_f * options[:stopband]
      numer = -20.0 * Math.log10(ripple) - 13
      denum = 14.6 * options[:transition]
      taps = (numer/denum).round
      type = options[:type] || :odd
      if type == :even
        taps +=1 if taps.odd?
      else
        taps +=1 if taps.even?
      end
      taps
    end
    module_function :kaiser_estimate
    
  end
end