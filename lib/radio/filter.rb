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
  
  # This generic Filter class will optimize by replacing its #call
  # with an optimized version from a module.  The type of data
  # and initializer options determine the module name to load.
  class Filter
    
    TYPES = %w{
      mix interpolate decimate fir
    }.collect(&:to_sym).freeze

    # Filters are built with mixing first and fir last.
    # Chain multiple filters to get other effects.
    # Make sure unused options don't test true.
    # Filter.new(:mix => phase_inc, :decimate => int, :fir => array)
    def initialize options
      @options = options
    end

    # The first call with data is when we decide which module is optimal.
    # The module #call functions are highly optimized for each scenario.
    def call data, &block
      if Complex === data[0]
        mod_name = 'Complex'
      elsif Float === data[0]
        mod_name = 'Float'
      else
        raise "Unknown data type: #{first.class}"
      end
      TYPES.each do |type|
        mod_name += type.to_s.capitalize if @options[type]
      end
      this_call = method :call
      extend eval mod_name
      if this_call == method(:call)
        raise "#{mod_name} must override #call(data)"
      end
      setup data
      call data, &block
    end
    
    # implement in modules, if you desire.
    # have everything call super, this will catch.
    def setup data
      # noop
    end
    
  end
end

