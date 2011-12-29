# 2D Array of numbers will be mapped to 1..127 colors.
# This 7-bit data is encoded uncompressed and left for
# http to compress. Background color reserved for future use.

class WaterfallImage
  
  COLOR_TABLE = (0..127).collect do |i|
    r = g = b = Math.log((i+16)**6.35)*18-312
    redshift = i - 64
    if redshift > 0
      b = g -= redshift * 3
    end
    b *= 0.95
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

    data.each_with_index do |vals, row|
      col = 0
      min = vals.min
      range = vals.max - min
      while col < vals.size
        # Uncompressed GIF trickery avoids bit packing too
        # 126 byte chunks with reset keeps LXW in 8 bit codes
        slice = vals.slice(col,126)
        # This 126 because palette is 1..127
        slice = slice.collect { |x| (x - min) / range * 126 + 1 }
        slice = slice.pack 'C*'
        newstuff = [
          slice.size+1,
          slice,
          0x80 # LZW reset
        ].pack('Ca*C')
        gif += newstuff
        col += 126
      end

    end

    gif += [
      0x01, # end image blocks
      0x81, # final image block: LZW end
      0x00, # end image blocks
      0x3B # end gif
    ].pack('C*')

    return gif
  
  end

end