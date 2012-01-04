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


begin
  # NArray can easily double filter performance
  # I had trouble subclassing NArray so we'll just extend it.
  require 'narray'
  class NArray
    def fir filter, pos
      (self * filter[size-pos..-1-pos]).sum
    end
  end
rescue LoadError => e
  # Pure Ruby fake NArray
  # This will work for all of ::Radio but not other
  # projects like ruby-fftw3 and ruby-coreaudio.
  class NArray < Array
    def self.float arg
      new arg, 0.0
    end
    def self.to_na arg
      new(arg).freeze
    end
    def fir filter, pos
      acc = 0.0
      index = size - pos
      each do |val|
        acc += val * filter[index]
        index += 1
      end
      acc
    end
  end
end