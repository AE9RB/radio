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


require 'eventmachine'
require 'thin'
require 'rack'

class Radio
  class Server
    
    def self.start
      
       app = Rack::Builder.new do
         use Rack::CommonLogger
         use Rack::ShowExceptions
         use Rack::Lint
         run Radio::HTTP.new
       end

      EventMachine.run {
        Rack::Handler::Thin.run app, :Port => 8080, :Host => '0.0.0.0'
      }

    end
    
  end
end
