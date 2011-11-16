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
        data += file.read @size
      else
        raise type
      end
    end
  end
  [fmt, data]
end

fmt, data = load_wav 'wav/bpsk8k.wav'
data.force_encoding('binary') 
radio = Radio::PSK31::Rx.new 'C', 1000

# "CQ CQ CQ de EA2BAJ EA2BAJ EA2BAJ\rPSE K\r"
p fmt
p radio.call data
