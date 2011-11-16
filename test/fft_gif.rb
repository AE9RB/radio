# Prototype FFT waterfall GIF generator in pure Ruby

# 2D Array of numbers will be mapped to 1..127 colors.
# This 7-bit data is encoded uncompressed and left for
# http to compress. Background color reserved for future use.

def fft_gif data, color_table

  gif = [
    'GIF87a', # Start Header
    data[0].size, # width
    data.size, #height
    0xF6, # 128 24-bit colors
    0x00, # background color index
    0x00, # aspect ratio
  ].pack 'a6vvCCC'

  gif += color_table.pack 'C*'

  gif += [
    0x2C, # Start Image Block
    0x0000, # Left position
    0x0000, # Top position
    data[0].size, # width
    data.size, #height
    0x00, # No color table, not interlaced
    0x07, # LZW code size
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
        0x80, # LZW reset
      ].pack('Ca*C')
      col += block_max
    end

  end

  gif += [
    0x01, # size of final image block
    0x81, # final image block: LZW end
    0x00, # end image blocks
    0x3B, # end gif
  ].pack('CCCC')

  return gif
  
end

# fake fft data
data = []
for row in 0...40
  for col in 0...720
    (data[row]||=[])[col] = rand * Math.sin(col.to_f/120+10)
  end
end

# linear green colors
color_table = (0..127).collect do |i|
  [0,i*2,0]
end.flatten

File.open('test.gif', 'wb') do |io|
  io.write fft_gif data, color_table
end
