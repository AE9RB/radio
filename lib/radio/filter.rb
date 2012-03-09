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
  # and initializer options determine the module to load.
  class Filter
    
    TYPES = %w{
      iq mix interpolate decimate fir agc
    }.collect(&:to_sym).freeze

    def initialize options
      @options = options
      @mod_name = ''
      TYPES.each do |type|
        @mod_name += type.to_s.capitalize if @options[type]
      end
      extend eval @mod_name
      setup
    end

    def call data, &block
      extend_by_data_type data
      call data, &block
    end

    def call! data, &block
      extend_by_data_type data
      call! data, &block
    end
    
    def setup
      # noop
    end
    
    private
    
    # If the base module didn't include a #call then it has
    # defined specialized calls for each data type.  We don't
    # know the actual data type until the first data arrives.
    def extend_by_data_type data
      mod_type = @mod_name + '::' + data[0].class.to_s
      if @fully_extended
        raise "#{mod_type} not providing #call or #call! method."
      end
      this_call = method :call
      extend eval mod_type
      @fully_extended = true
    end
    
  end
end

