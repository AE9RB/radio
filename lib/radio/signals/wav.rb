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
    class File
      class WAV
        
        attr_reader :rate
        
        def initialize options
          @file = ::File.new options[:id]
          #TODO validate header instead?
          @file.read 12 # discard header
          @rate = options[:rate].to_i
          if input = options[:input]
            @channel_i = input[0]
            @channel_q = input[1]
          end
          @data = [next_data]
          @time = Time.now
        end
        
        def in samples
          sample_size = @channels * (@bit_sample/8)
          @time += 1.0/(rate/samples)
          sleep [0,@time-Time.now].max
          while @data.reduce(0){|a,b|a+b.size} < samples * sample_size
            @data.push next_data
          end
          if input_channels > 1
            out = NArray.scomplex samples
          else
            out = NArray.sfloat samples
          end
          i = 0
          while i < samples
            if @data.first.size/sample_size > samples-i
              out[i..-1] = convert @data.first[0...(samples-i)*sample_size]
              @data[0] = @data.first[(samples-i)*sample_size..-1]
              i = samples
            else
              converted_data = convert @data.shift
              out[i...(i+converted_data.size)] = converted_data
              i += converted_data.size
            end
          end
          out
        end
        
        def input_channels
          return 2 if @channel_q and @channels > 1
          1
        end
        
        def output_channels
          0
        end
        
        def stop
          @file.close
        end
        
        private
        
        def convert d
          out = case @bit_sample
          when 8 then NArray.to_na(d,NArray::BYTE).to_f.collect!{|v|(v-128)/127}
          when 16 then NArray.to_na(d,NArray::SINT).to_f.div! 32767
          # when 24 then NArray.to_na(d,NArray::???).to_f.collect!{|v|(v-8388608)/8388607}
          else
            raise "Unsupported sample size: #{@bit_sample}" 
          end
          return out if input_channels == 1 and @channels == 1
          out.reshape! @channels, out.size/@channels
          if input_channels == 1
            out[@channel_i,true]
          else
            c_out = NArray.scomplex out[0,true].size
            c_out[0..-1] = out[@channel_i,true]
            c_out.imag = out[@channel_q,true]
            c_out
          end
        end
        
        #TODO read data in chunks smaller than size (which is often the whole file)
        def next_data
          loop do
            until @file.eof?
              type = @file.read(4)
              size = @file.read(4).unpack("V")[0].to_i
              case type
              when 'fmt '
                fmt = @file.read(size)
                @id = fmt.slice(0,2).unpack('c')[0]
                @channels = fmt.slice(2,2).unpack('c')[0]
                @rate = fmt.slice(4,4).unpack('V').join.to_i
                @byte_sec = fmt.slice(8,4).unpack('V').join.to_i
                @block_size = fmt.slice(12,2).unpack('c')[0]
                @bit_sample = fmt.slice(14,2).unpack('c')[0]
                next
              when 'data'
                return @file.read size
              else
                raise "Unknown GIF type: #{type}"
              end
            end
            @file.rewind
            @file.read 12 # discard header
          end
        end
        
      end
    end
  end
end

