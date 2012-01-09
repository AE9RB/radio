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


require 'rack'
require 'erb'
  
class Radio
  class HTTP
    
    MOUNTS = [
      ['', File.expand_path(File.join(File.dirname(__FILE__), '../../../www'))]
    ]
    
    class Server

      ENV_THREAD_BYPASS = 'radio.thread_bypass'

      def initialize
        @working_dir = Dir.getwd
      end
      
      # Thin can run some processes in threads if we provide the logic.
      # Static files are served without deferring to a thread.
      # Everything else is tried in the EventMachine thread pool.
      def deferred? env
        path_info = Rack::Utils.unescape(env['PATH_INFO'])
        return false if path_info =~ /\.(\.|erb$)/ # unsafe '..' and '.erb'
        MOUNTS.each do |path, dir|
          if path_info =~ %r{^#{Regexp.escape(path)}(/.*|)$}
            filename = File.join(dir, $1)
            Dir.chdir @working_dir
            response = FileResponse.new(env, filename)
            if !response.found? and File.extname(path_info) == ''
              response = FileResponse.new(env, filename + '.html')
            end
            if response.found?
              env[ENV_THREAD_BYPASS] = response
              return false
            end
            env[ENV_THREAD_BYPASS] = filename
          end
        end
        return true
      end

      # Rack interface.
      # @param (Hash) env Rack environment.
      # @return (Array)[status, headers, body]
      def call(env)
        # The preprocessing left us with nothing, a response,
        # or a filename that we should try to run.
        case deferred_result = env.delete(ENV_THREAD_BYPASS)
        when String
          filename = deferred_result
          response = Script.new(env, filename).response
          if response.header["X-Cascade"] == 'pass'
            index_response = Script.new(env, filename + '/index').response
            response = index_response unless index_response.header["X-Cascade"] == 'pass'
          end
          response.finish
        when NilClass
          not_found
        else
          deferred_result.finish
        end
      end

      # Status 404 with X-Cascade => pass.
      # @return (Array)[status, headers, body]
      def not_found
        return @not_found if @not_found
        body = "404 Not Found\n"
        @not_found = [404, {'Content-Type' => 'text/plain',
               'Content-Length' => body.size.to_s,
               'X-Cascade' => 'pass'},
         [body]]
        @not_found
      end

    end
  end
end
