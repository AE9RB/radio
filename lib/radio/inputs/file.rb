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
  module Input
    class File
      
      def self.status
        "Loaded: %d files found" % sources.size
      end
      
      def self.sources
        result = {}
        files = Dir.glob ::File.expand_path '../../../../test/wav/**/*.wav', __FILE__
        files.each do |file|
          begin
            f = new file, 0, 0, 1
          rescue Exception => e
            next
          end
          result[file] = {
            name: file,
            rates: [f.rate],
            channels: f.channels
          }
        end
        result
      end
      
      # You can load any file, not just the ones in sources.
      def initialize id, rate, channel_i, channel_q
        self.class.constants.each do |x|
          klass = eval x.to_s
          @reader = klass.new id, rate, channel_i, channel_q rescue nil
          break if @reader
        end
        raise 'Unknown format' unless @reader
      end
      
      def method_missing meth, *args, &block
        @reader.send meth, *args, &block
      end
      
    end
  end
end

