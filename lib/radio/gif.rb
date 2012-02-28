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


# 2D Array of numbers will be mapped to 1..127 colors.
# This 7-bit data is encoded uncompressed and left for
# http to compress. Background color reserved for future use.

class Radio
  class Gif
  
    # This is a very fast GIF generator for waterfalls.
    # It requires 128 RGB colors, the first is unused and
    # reserved for transparency if we ever need it.
    # data is expected to be an NArray
    def self.waterfall colors, data, min=nil, max=nil
      width = data[true,0].size
      height = data[0,true].size
      gif = [
        'GIF87a', # Start Header
        width,
        height,
        0xF6, # 128 24-bit colors
        0x00, # background color index
        0x00 # aspect ratio
      ].pack 'a6vvCCC'
      gif += colors.flatten.pack 'C*'
      gif += [
        0x2C, # Start Image Block
        0x0000, # Left position
        0x0000, # Top position
        width,
        height,
        0x00, # No color table, not interlaced
        0x07 # LZW code size
      ].pack('CvvvvCC')
      data = data.reshape(data.size)
      min ||= data.min
      max ||= data.max
      range = [1e-99, max - min].max
      data -= min # will dup
      data.div!(range).mul!(126).add!(1)
      # add in a frame+reset every 126 plus the 4 byte end block
      predict = gif.size + (data.size+125) / 126 * 2 + data.size + 4
      out = NArray.byte predict
      out[0...gif.size] = NArray.to_na gif, NArray::BYTE, gif.size
      i = 0
      pos = gif.size
      while i < data.size
        qty = [126,data.size-i].min
        out[pos] = qty+1
        pos+=1
        if qty == 1
          out[pos] = data[i]
        else
          out[pos...pos+qty] = data[i...i+qty]
        end
        pos+=qty
        out[pos] = 0x80 # LZW reset
        pos+=1
        i += qty
      end
      out[pos] = 0x01, # end image blocks
      out[pos+1] = 0x81, # final image block: LZW end
      out[pos+2] = 0x00, # end image blocks
      out[pos+3] = 0x3B # end gif
      out.to_s
    end

  end
end