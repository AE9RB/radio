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
    
    module Deferred
      
      # Returns true for pages needing to sleep on a thread.
      def deferred? env
        env['PATH_INFO'] =~ %r{/waterfall}
      end

    end
    
    MOUNTS = [
      ['', File.expand_path(File.join(File.dirname(__FILE__), 'http'))]
    ]

    ENGINES = {
      '.erb' => Proc.new do |script, locals|
        erb = ::ERB.new(File.read(script.render_stack.last), nil, '-')
        erb.filename = script.render_stack.last
        script.extend ::ERB::Util
        script_binding = script.instance_eval{binding}
        script.send(:instance_variable_set, '@_radio_locals', locals)
        set_locals = locals.keys.map { |k| "#{k}=@_radio_locals[#{k.inspect}];" }.join
        eval set_locals, script_binding
        erb.result script_binding
      end
    }

    # A Script instance is the context in which scripts are rendered.
    # It inherits everything from Rack::Request and supplies a Response instance
    # you can use for redirects, cookies, and other controller actions.
    class Script < Rack::Request

      class NotFound < StandardError
      end

      class RenderStackOverflow < StandardError
      end
      
      def initialize(env, filename)
        super(env)
        @render_stack = []
        @response = original_response = Rack::Response.new
        @session = Session.prepare self, @response
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

      attr_reader :session

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
          ENGINES.each do |ext, engine|
            files2 = [filename1+ext]
            files2 << filename1.gsub(/.html$/, ext) if File.extname(filename1) == '.html'
            unless filename1 =~ /^_/ or render_stack.empty?
              files2 = files2 + files2.collect {|f| "#{File.dirname(f)}/_#{File.basename(f)}"} 
            end
            files2.each do |filename2|
              if File.file?(filename2) and File.readable?(filename2)
                if render_stack.empty?
                  response.header["Content-Type"] = Rack::Mime.mime_type(File.extname(filename1), 'text/html')
                end
                render_stack.push filename2
                result = engine.call self, locals
                render_stack.pop
                return result
              end
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
    
    
    class FileResponse
    
      def initialize(env, filename, content_type = nil)
        @env = env
        @filename = filename
        @status = 200
        @headers = {}
        @body = []
      
        begin
          raise Errno::EPERM unless File.file?(filename) and File.readable?(filename)
        rescue SystemCallError
          @body = ["404 Not Found\n"]
          @headers["Content-Length"] = @body.first.size.to_s
          @headers["Content-Type"] = 'text/plain'
          @headers["X-Cascade"] = 'pass'
          @status = 404
          return
        end
      
        # Caching strategy
        mod_since = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE']) rescue nil
        last_modified = File.mtime(filename)
        @status = 304 and return if last_modified == mod_since
        @headers["Last-Modified"] = last_modified.httpdate
        if env['QUERY_STRING'] =~ /^[0-9]{9,10}$/ and last_modified == Time.at(env['QUERY_STRING'].to_i)
          @headers["Cache-Control"] = 'max-age=86400, public' # one day
        else
          @headers["Cache-Control"] = 'max-age=0, private, must-revalidate'
        end
      
        # Sending the file or reading an unknown length stream to send
        @body = self
        unless size = File.size?(filename)
          @body = [File.read(filename)]
          size = @body.first.respond_to?(:bytesize) ? @body.first.bytesize : @body.first.size
        end
        @headers["Content-Length"] = size.to_s
        @headers["Content-Type"] = content_type || Rack::Mime.mime_type(File.extname(filename), 'text/plain')
      end
    
      # Support using self as a response body.
      # @yield [String] 8k blocks
      def each
        File.open(@filename, "rb") do |file|
          while part = file.read(8192)
            yield part
          end
        end
      end

      # Filename attribute.
      # Alias is used by some rack servers to detach from Ruby early.
      # @return [String]
      attr_reader :filename
      alias :to_path :filename

      # Was the file in the system and ready to be served?
      def found?
        @status == 200 or @status == 304
      end
  
      # Present the final response for rack.
      # @return (Array)[status, headers, body]
      def finish
        [@status, @headers, @body]
      end

    end
    
    def initialize
      @working_dir = Dir.getwd
    end
    
    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
    def call(env)
      path_info = Rack::Utils.unescape(env['PATH_INFO'])
      return not_found if path_info.include? '..' # unsafe
      MOUNTS.each do |path, dir|
        if path_info =~ %r{^#{Regexp.escape(path)}(/.*|)$}
          filename = File.join(dir, $1)
          Dir.chdir @working_dir
          response = FileResponse.new(env, filename)
          if !response.found? and File.extname(path_info) == ''
            response = FileResponse.new(env, filename + '.html')
          end
          unless response.found?
            response = Script.new(env, filename).response
            if response.header["X-Cascade"] == 'pass'
              index_response = Script.new(env, filename + '/index').response
              response = index_response unless index_response.header["X-Cascade"] == 'pass'
            end
          end
          return response.finish
        end
      end
      not_found
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
