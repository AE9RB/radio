# This will become an abstraction to gems that support access to
# audio frequency devices.  That may be a direct sound card interface,
# javax.sound.sampled, or an audio server such as ourself or PulseAudio.

require 'coreaudio'
require 'thread'

class Audio
  
  # Returns Array of Audio objects with #first being the OS default.
  def self.inputs
    @inputs ||= lambda {
      default_devid = CoreAudio.default_input_device.devid
      devs = CoreAudio.devices.collect { |d| new d }
      devs.sort! do |a,b| 
        case default_devid
          when a.id then -1
          when b.id then 1
          else 0
        end
      end
    }.call
  end
  
  # Searches inputs with priority to find first:
  # 1. Exact match on id and name
  # 2. Match on name only
  # 3. Not Found
  def self.find_input id, name
    exact = fuzzy = nil
    inputs.each do |dev|
      exact ||= dev if dev.id == id and dev.name == name
      fuzzy ||= dev if dev.name == name
    end
    exact or fuzzy
  end
    
  attr_reader :id, :name
  
  # Use Audio.inputs to get suitable instances.
  # Multiple instances to the same device are less efficient.
  def initialize dev
    @dev = dev
    @id = dev.devid
    @name = dev.name
    @queues = {}
    @sid = -1
    @semaphore = Mutex.new
  end
  
  # Returns a Queue instance that will populate with
  # enumerations of floats from -1.0..1.0.
  def subscribe channel=0
    queue = Queue.new
    do_start = false
    @sid += 1
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
  
  # RFC791 suggests 576 bytes as the minimum MTU for any host.
  # 16 packets/sec in PCM 8x8000 format fits comfortably.
  def thread buf
    channels = [] # don't transform a sample more than once
    loop do
      data = buf.read 500
      channels.clear
      @semaphore.synchronize do
        @queues.each do |queue, channel|
          # CoreAudio range of -32767..32767 makes easy conversion to -1.0..1.0
          queue.push channels[channel] ||= data[channel,true].to_f/32767
        end
      end
    end
  end
  
  def start
    unless @dev.actual_rate == 8000.0
      puts "FATAL ERROR: Device #{@dev.name.dump} not 8000.0 Hz."
      puts 'Use "Applications/Utilities/Audio MIDI Setup" to adjust.'
      exit 1
    end
    @buf ||= @dev.input_buffer(@dev.input_stream.channels * 4000)
    @thread ||= Thread.new @buf, &method(:thread)
    @buf.start
  end
  
  def stop
    @buf.stop
    @thread.kill.join
    @thread = nil
  end
  
end

if $0 == __FILE__

  aud_dev = Audio.inputs[0]
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
