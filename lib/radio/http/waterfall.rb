# 2D Array of numbers will be mapped to 1..127 colors.
# This 7-bit data is encoded uncompressed and left for
# http to compress. Background color reserved for future use.

class WaterfallImage
  
  COLOR_TABLE = (0..127).collect do |i|
    g = i * 1.2
    b = i * 2
    r = i - 110
    if r < 0
      r = (g + b) / 3
    else
      r = r * 15
    end
    b = b - (r/2)
    b = 0 if b < 0
    [r,g,b]
  end.flatten.pack 'C*'
  
  def self.gif data

    gif = [
      'GIF87a', # Start Header
      data[0].size, # width
      data.size, # height
      0xF6, # 128 24-bit colors
      0x00, # background color index
      0x00 # aspect ratio
    ].pack 'a6vvCCC'

    gif += COLOR_TABLE

    gif += [
      0x2C, # Start Image Block
      0x0000, # Left position
      0x0000, # Top position
      data[0].size, # width
      data.size, # height
      0x00, # No color table, not interlaced
      0x07 # LZW code size
    ].pack('CvvvvCC')

    min = max = data[0][0]
    data.each do |row|
      row.each do |val|
        min = [min, val].min
        max = [max, val].max
      end
    end
    range = max - min
    block_max = 126 # or else LZW exceeds 8 bits

    data.each_with_index do |vals, row|
      col = 0
      while col < vals.size
        slice = vals.slice(col,block_max)
        slice = slice.collect { |x| (x - min) / range * 127 + 1 }
        slice = slice.pack 'C*'
        gif += [
          slice.size+1,
          slice,
          0x80 # LZW reset
        ].pack('Ca*C')
        col += block_max
      end

    end

    gif += [
      0x02, # end image blocks
      0x00, # keeps FF happy
      0x81, # final image block: LZW end
      0x00, # end image blocks
      0x3B # end gif
    ].pack('C*')

    return gif
  
  end

end