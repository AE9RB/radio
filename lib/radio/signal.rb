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
  module Signal
    
    # Keep this namespace clean because we search inputs by
    # finding the classes from Radio::Inputs.constants.
    
    # Drivers are supposed to fail silently if they can't find
    # dependencies. This allows us to present a basic debug screen.
    def self.status
      s = {}
      constants.collect do |input_name|
        s[input_name] = eval(input_name.to_s).status
      end
      s
    end
    
    # Consolidate all sources from all inputs and add the class name to the keys.
    def self.devices
      s = {}
      constants.each do |type|
        eval(type.to_s).devices.each do |id, source|
          s[[type, id]] = source
        end
      end
      s
    end
    
    # You can't new a module so this switches into the specific class.
    def self.new options
      type = options.delete :type
      options[:output] = [options[:output]].flatten if options[:output]
      options[:input] = [options[:input]].flatten if options[:input]
      unless constants.include? type.to_sym
        raise NameError, "uninitialized constant Radio::Input::#{type}"
      end
      device = eval(type.to_s).new options
      # Ask for and discard the first sample to report errors here
      begin
        device.out NArray.scomplex(1) if device.output_channels == 2
        device.out NArray.sfloat(1) if device.output_channels == 1
        device.in 1 if device.input_channels > 0
      rescue Exception => e
        device.stop
        raise e
      end
      device
    end
    
  end
end

