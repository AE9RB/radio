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


# This is unfinished, unused, and needs expiration management.
# We'll definitely want sessions working for authentication,

class Radio
  class HTTP
    class Session
  
      CODES = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
      COOKIE_KEY = 'ham21-radio-session'
  
      def self.prepare request, response
        @sessions ||= {}
        session_id = request.cookies[COOKIE_KEY]
        session = @sessions[session_id]
        unless session
          session_id = (0...24).collect{CODES.sample}.join
          session = @sessions[session_id] = new
          Rack::Utils.set_cookie_header!(response.headers, COOKIE_KEY, session_id)
        end
        session
      end
  
      def initialize
      end
  
    end
  end
end
