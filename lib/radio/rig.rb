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

  class Rig
    
    include Spectrum
    include Rx
    include LO
    include SSB
  
    def initialize
      @semaphore = Mutex.new
      @listeners = {}
      @listeners_mutex = Mutex.new
      super
    end
    
    def register queue
      @listeners_mutex.synchronize do
        @listeners[queue] = true
      end
    end

    def deregister queue
      @listeners_mutex.synchronize do
        @listeners.delete queue
      end
    end
    
    def rate
      @semaphore.synchronize do
        return @rx.rate if @rx
        return @tx.rate if @tx
        return 0
      end
    end
    
    def iq?
      @semaphore.synchronize do
        return @rx.channels == 2 if @rx
        return @tx.channels == 2 if @tx
        return false
      end
    end
    
    private
    
    def distribute_to_listeners data
      @listeners_mutex.synchronize do
        @listeners.each {|k,v| k << data}
      end
    end

  end
end