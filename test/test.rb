require_relative '../lib/radio'

# Basic loading of uncompressed wav files for testing
def load_wav filename
  sample_rate = nil
  fmt = nil
  data = ''
  File.open(filename) do |file|
    head = file.read(12)
    until file.eof?
      type = file.read(4)
      size = file.read(4).unpack("V")[0].to_i
      case type
      when 'fmt '
        fmt = file.read(size)
        fmt = {
          :id => fmt.slice(0,2).unpack('c')[0],
          :channel => fmt.slice(2,2).unpack('c')[0],
          :hz => fmt.slice(4,4).unpack('V').join.to_i,
          :byte_sec => fmt.slice(8,4).unpack('V').join.to_i,
          :block_size => fmt.slice(12,2).unpack('c')[0],
          :bit_sample => fmt.slice(14,2).unpack('c')[0]
        }
      when 'data'
        data += file.read size
      else
        raise type
      end
    end
  end
  [fmt, data]
end

# Generate a float enumerator for binary string audio data.
# Packing is defined with Array#pack/String#unpack formats.
# Usage: floats = $iterators['C'].enum_for(:call, data)
# 'C' should be almost as fast as String#each_byte.
# If slow, you probably need to: data.force_encoding('binary')
$iterators = Hash.new do |hash, packing|
  packing = packing.to_s.dup
  sample_size = [0].pack(packing).size
  case ("\x80"*16).unpack(packing)[0]
  when 128
    max = 128
    offset = -128
  when -128
    max = 128
    offset = 0
  when 32768 + 128
    max = 32768
    offset = -32768
  when -32768 + 128
    max = 32768
    offset = 0
  else
    raise 'unable to interpret packing format'
  end
  hash[packing] = Proc.new do |data, &block|
    pos = 0
    size = data.size
    while pos < size
      sample = data.slice(pos,sample_size).unpack(packing)[0] || 0
      block.call (sample + offset).to_f / max
      pos += sample_size
    end
  end
end


fmt, data = load_wav 'wav/bpsk8k.wav'
data.force_encoding('binary') 
radio = Radio::PSK31::Rx.new 1000

# "CQ CQ CQ de EA2BAJ EA2BAJ EA2BAJ\rPSE K\r"
i =  $iterators['C'].enum_for(:call, data)
radio.call(i.to_a){|o| p o}
