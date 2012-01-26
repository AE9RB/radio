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


require 'thread'

class RetiredAudio
  
  # Returns Array of Audio objects with #first being the OS default.
  def self.inputs
    @inputs ||= [new]
  end
  
  def initialize
    @queues = {}
    @semaphore = Mutex.new
  end
  
  # Returns a Queue instance that will populate with
  # enumerations of floats from -1.0..1.0.
  def subscribe channel=0
    queue = Queue.new
    do_start = false
    @semaphore.synchronize do
      do_start = @queues.empty?
      @queues[queue] = channel
    end
    start if do_start
    queue
  end
  
  def unsubscribe queue
    do_stop = false
    @semaphore.synchronize do
      @queues.delete queue
      do_stop = @queues.empty?
    end
    stop if do_stop
  end
  
  private
  
  def thread
    filename = File.expand_path '../../../../test/wav/bpsk8k.wav', __FILE__
    fmt, data = load_wav filename
    data.force_encoding('binary')

    i = ITERATORS['C'].enum_for(:call, data)
    j = []
    i.each_slice(512) do |s|
      j << s if s.size == 512
    end

    loop do
      j.each do |s|
        sleep 0.064
        @semaphore.synchronize do
          @queues.each do |queue, clannel|
            queue.push s
          end
        end
      end
    end
  end
  
  def start
    @thread ||= Thread.new &method(:thread)
  end
  
  def stop
    @thread.kill.join
    @thread = nil
  end
  
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
  
  ITERATORS = Hash.new do |hash, packing|
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
  
  
end

if $0 == __FILE__

  aud_dev = RetiredAudio.inputs[0]
  queue = aud_dev.subscribe
  
  25.times do
    data = queue.pop
    a = []
    x = Time.now
    data.each do |f|
      a << f if a.size < 5
    end
    x = Time.now-x
    p [Time.now, a]
  end
  
  aud_dev.unsubscribe queue
  
end
