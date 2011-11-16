begin
  # NArray can easily double filter performance
  # I had trouble subclassing NArray so we'll just extend it.
  require 'narray'
  class NArray
    def fir filter, pos
      (self * filter[size-pos..-1-pos]).sum
    end
  end
rescue LoadError => e
  # Pure Ruby fake NArray
  # This will work for all of ::Radio but not other
  # projects like ruby-fftw3 and ruby-coreaudio.
  class NArray < Array
    def self.float arg
      new arg, 0.0
    end
    def self.to_na arg
      new(arg).freeze
    end
    def fir filter, pos
      acc = 0.0
      index = size - pos
      each do |val|
        acc += val * filter[index]
        index += 1
      end
      acc
    end
  end
end