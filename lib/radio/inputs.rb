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
  module Inputs
    
    # Keep this namespace clean because we search inputs by
    # finding the classes from Radio::Inputs.constants.
    
    # Drivers are supposed to fail silently if they can't find
    # dependencies. This allows us to present a basic debug screen.
    def self.status
      s = {}
      Radio::Inputs.constants.collect do |input_name|
        s[input_name] = eval(input_name.to_s).status
      end
      s
    end
    
    # Consolidate all sources from all inputs and add the class name to the keys.
    def self.sources
      s = {}
      Radio::Inputs.constants.each do |input_name|
        eval(input_name.to_s).sources.each do |id, source|
          s[[input_name, id]] = source
        end
      end
      s
    end
    
    # You can't new a module so this switches into the specific class.
    def self.new id, rate, channel_i, channel_q=nil
      input_name, id = id
      # defend the eval
      unless Radio::Inputs.constants.include? input_name.to_sym
        raise NameError, "uninitialized constant Radio::Inputs::#{input_name}"
      end
      eval(input_name.to_s).new id, rate, channel_i, channel_q
    end
    
  end
end


if $0 == __FILE__
  Dir.glob(File.expand_path('inputs/*.rb', File.dirname(__FILE__))).each do |filename|
    require filename
  end
  p Radio::Inputs.status
  p Radio::Inputs.sources
  # s = Radio::Inputs.sources.first
  # id = s[0]
  # rate = s[1][:rates][0]
  # p Radio::Inputs.new(id,rate,0)
end
