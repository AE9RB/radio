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
  module Controls
    
    # Support for Icom CI-V
    # http://www.plicht.de/ekki/civ/civ-p0a.html
    
    # The serialport gem is not flexible with device names, so:
    # sudo ln -s /dev/cu.usbserial-A600BVS2 /dev/cuaa0

    # You can use this somewhat asynchronously but if you queue up
    # multiple commands of the same type or multiple commands that
    # return OK/NG then it can't be perfect. This is a limitation
    # of the CI-V protocol, not the implementation.  While this makes
    # my inner engineer cringe, it does work perfectly fine for
    # user interfaces and typical applications.
    class CIV
      
      # An exception is raised when commands do not get a response.
      # RETRY should be low enough to make many attempts before a timeout.
      TIMEOUT = 0.5
      
      # Commands are retried automatically when we're not seeing messages.
      # This happens when you have a collision while transmitting.
      RETRY = 0.05
      
      # Cache responses briefly
      DWELL = 0.1 #seconds
      
      # All commands that only return OK or NG.
      OKNG = [5, 6] #TODO
      
      def initialize options={}
        @semaphore = Mutex.new
        @queue = Queue.new
        @host = options[:host]|| 0xE0 # my address
        @device = options[:device]|| 0x50 # radio address
        port = options[:port]|| 0
        @baud = options[:baud]|| 9600
        bits = options[:bits]|| 8
        stop = options[:stop]|| 1
        parity = options[:parity]|| SerialPort::NONE
        @io = SerialPort.new port, @baud, bits, stop, parity
        @state = :WaitPreamble1
        @carrier_sense = false
        @last_message = Time.now
        @machine = Thread.new &method(:machine)
        @watchdog = Thread.new &method(:watchdog)
        begin
          lo
        rescue Exception => e
          raise "Icom CI-V radio not found"
        end
      end
      
      def stop
        @machine.kill
        @watchdog.kill
        @machine.join
        @watchdog.join
        @io.close
      end
      
      def lo
        @semaphore.synchronize do
          return @lo if @lo and Time.now < @lo_expires
        end
        lo = command 3
        @semaphore.synchronize do
          @lo_expires = Time.now + DWELL
          @lo = lo
        end
      end

      def lo= freq
        unless command 5, num_to_bcd(freq * 1000000, 5)
          raise 'Unsupported frequency'
        end
        @semaphore.synchronize do
          @lo = nil
        end
      end
      
      def command type, data_or_array = nil
        cmd = "\xFE\xFE#{@device.chr}\xE0#{type.chr}".force_encoding("binary")
        if Array === data_or_array
          cmd += data_or_array.pack('C*').force_encoding("binary")
        else
          cmd += "#{data_or_array}".force_encoding("binary")
        end
        cmd += "\xfd".force_encoding("binary")
        queue = Queue.new
        @semaphore.synchronize do
          @io.write cmd
          @queue << [queue, type, cmd, Time.now] unless type < 2
        end
        if type < 2
          true
        else
          result = queue.pop
          raise result if Exception === result
          result
        end
      end
      
      private
      
      def bcd_to_num s
        mult = 1
        o = 0
        s.each_byte do |b|
          o += mult * (((b & 0xf0) >> 4)*10 + (b & 0xf))
          mult *= 100
        end
        o
      end
      
      def num_to_bcd n, count
        n = n.to_i
         a = []
         count.times do
            a << ((n % 10) | ((n/10) % 10) << 4)
            n /= 100
         end
         a
      end
      
      def watchdog
        loop do
          elapsed = nil
          @semaphore.synchronize do
            @last_message = Time.now if @queue.empty?
            elapsed = Time.now - @last_message
            if elapsed > RETRY
              # A sent message must have got lost in collision
              # We only need to resend one to get things rolling again
              cmd_queue, cmd_type, cmd_msg, cmd_time = @queue.pop
              if Time.now - cmd_time > TIMEOUT
                cmd_queue << RuntimeError.new("Command #{cmd_type} timeout.")
              end
              send_when_clear cmd_msg
              @queue << [cmd_queue, cmd_type, cmd_msg, cmd_time]
              elapsed = 0
            end
          end
          sleep RETRY - elapsed
        end
      end
      
      def send_when_clear cmd_msg
        # Look to make sure there isn't any data moving on the
        # RS-422 bus before we begin sending.
        loop do
          @carrier_sense = false
          # several bytes worth of time
          sleep 1.0 / (@baud / 50)
          break unless @carrier_sense
        end
        @io.write cmd_msg
      end
      
      def machine
        loop do
          c = @io.getbyte
          @carrier_sense = true # Let's see if booleans are thread safe
          @state = :WaitPreamble1 if c == 0xFC
          case @state
          when :WaitPreamble1
            @state = :WaitPreamble2 if c == 0xFE
          when :WaitPreamble2
            if c == @host or c == 0x00
              @state = :WaitFmAdress
            else
              @state = :WaitPreamble2
            end
          when :WaitFmAdress
            if c == @device
              @incoming = ''
              @state = :WaitCommand
            else
              @state = :WaitPreamble1
            end
          when :WaitCommand
            if c < 0x1F or c == 0xFA or c == 0xFB
              @command = c
              @state = :WaitFinal
            else
              @state = :WaitPreamble1
            end
          when :WaitFinal
            if c == 0xFD
              process @command, @incoming
              @state = :WaitPreamble1
            elsif c > 0xFD
              @state = :WaitPreamble1
            else
              @incoming += c.chr
            end
          end
        end
      end
      
      def process type, data
        @last_message = Time.now
        @semaphore.synchronize do
          queue = nil
          redos = []
          while !@queue.empty?
            queue, cmd_type, cmd_msg, cmd_time = @queue.pop
            #TODO validate response length is correct or retry
            break if cmd_type == type or OKNG.include? cmd_type
            redos << [queue, cmd_type, cmd_msg, cmd_time]
            queue = nil
          end
          redos.each do |cmd_queue, cmd_type, cmd_msg, cmd_time|
            send_when_clear cmd_msg
            @queue << [cmd_queue, cmd_type, cmd_msg, cmd_time]
          end
          return unless queue
          case type
          when 0x03
            queue.push bcd_to_num(data).to_f/1000000
          when 0xFB # OK
            queue.push true
          when 0xFA # NG no good
            queue.push false
          else
            #TODO logger
            p "Unsupported message: #{type} #{data.dump}"
          end
        end
      end
      
    end
  end
end

