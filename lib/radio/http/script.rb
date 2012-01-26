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


require 'erb'
  
class Radio

  class HTTP
    
    # A Script instance is the context in which scripts are rendered.
    # It inherits everything from Rack::Request and supplies a Response instance
    # you can use for redirects, cookies, and other controller actions.
    class Script < Rack::Request
      
      include ERB::Util

      class NotFound < StandardError
      end

      class RenderStackOverflow < StandardError
      end
      
      def initialize(env, filename)
        super(env)
        @render_stack = []
        @response = original_response = Rack::Response.new
        rendering = render(filename)
        if @response == original_response and @response.empty?
          @response.write rendering
        end
      rescue RenderStackOverflow, NotFound => e
        if @render_stack.size > 0
          # Make errors appear from the render instead of the engine.call
          e.set_backtrace e.backtrace[1..-1]
          raise e 
        end
        @response.status = 404
        @response.write "404 Not Found\n"
        @response.header["X-Cascade"] = "pass"
        @response.header["Content-Type"] = "text/plain"
      end

      # After rendering, #finish will be sent to the client.
      # If you replace the response or add to the response#body, 
      # the script engine rendering will not be added.
      # @return [Rack::Response]
      attr_accessor :response

      # An array of filenames representing the current render stack.
      # @example
      #  <%= if render_stack.size == 1
      #        render 'html_version' 
      #      else
      #        render 'included_version'
      #      end 
      #  %>
      # @return [<Array>]
      attr_reader :render_stack

      # Render another Script.
      # @example view_test.erb
      #   <%= render 'util/logger_popup' %>
      # @param (String) filename Relative to current Script.
      # @param (Hash) locals Local variables for the Script.
      def render(filename, locals = {})
        if render_stack.size > 100
          # Since nobody sane should recurse through here, this mainly
          # finds a render self that you might get after a copy and paste
          raise RenderStackOverflow 
        elsif render_stack.size > 0
          # Hooray for relative paths and easily movable files
          filename = File.expand_path(filename, File.dirname(render_stack.last))
        else
          # Underbar scripts are partials by convention; keep them from rendering at root
          filename = File.expand_path(filename)
          raise NotFound if File.basename(filename) =~ /^_/
        end
        ext = File.extname(filename)
        files1 = [filename]
        files1 << filename + '.html' if ext == ''
        files1 << filename.sub(/.html$/,'') if ext == '.html'
        files1.each do |filename1|
          files2 = [filename1+'.erb']
          files2 << filename1.gsub(/.html$/, '.erb') if File.extname(filename1) == '.html'
          unless filename1 =~ /^_/ or render_stack.empty?
            files2 = files2 + files2.collect {|f| "#{File.dirname(f)}/_#{File.basename(f)}"} 
          end
          files2.each do |filename2|
            if File.file?(filename2) and File.readable?(filename2)
              if render_stack.empty?
                response.header["Content-Type"] = Rack::Mime.mime_type(File.extname(filename1), 'text/html')
              end
              render_stack.push filename2
              erb = ::ERB.new(File.read(filename2), nil, '-')
              erb.filename = filename2
              set_locals = locals.keys.map { |k| "#{k}=locals[#{k.inspect}];" }.join
              instance_binding = instance_eval{binding}
              eval set_locals, instance_binding
              result = erb.result instance_binding
              render_stack.pop
              return result
            end
          end
        end
        raise NotFound
      end

      # Helper for finding files relative to Scripts.
      # @param [String] filename
      # @return [String] absolute filesystem path
      def expand_path(filename, dir=nil)
        dir ||= File.dirname render_stack.last
        File.expand_path filename, dir
      end

    end


  end

end
