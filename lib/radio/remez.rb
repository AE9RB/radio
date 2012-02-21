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


# This uses similar variable names and similar logic as a
# popular C implementation of the Parks McClellan algorithm
# which is based on an old FORTRAN implementation.
# I did this Ruby version in a hurry so for comments, see the C:
# http://www.janovetz.com/  Jake Janovetz (janovetz@uiuc.edu) 


class Radio

  # Instances of Remez will act as the result array.  The result
  # is lazily generated just-in-time for the first use.  This
  # allows for CONSTANT=Remez.new assignments without the huge
  # penalty to application startup.  To force an immediate result,
  # just ask for and retain #to_a.

  class Remez
    
    # :numtaps is the size of the computed array of coefficients
    # :bands
    # :desired
    # :weights
    # :type may be in [:bandpass, :differentiator, :hilbert]
    # :maxiterations won't raise error when negative
    def initialize options
      @options = options
    end

    def method_missing name, *opts, &block
      remez unless @h
      @h.send name, *opts, &block
    end
    
    private
    
    def remez
      numtaps = @options[:numtaps].to_i
      bands = @options[:bands].flatten
      des = @options[:desired]
      weight = @options[:weights]
      type = @options[:type].to_sym
      griddensity = @options[:griddensity] || 16
      maxiterations = @options[:maxiterations] || 40

      numband = des.size
      raise 'weight.size mismatch' unless weight.size == numband
      raise 'bands.size mismatch' unless bands.size == numband * 2
      
      symmetry = (type == :bandpass) ? :positive : :negative
      
      @r = numtaps / 2
      @r += 1 if numtaps.odd? and symmetry == :positive
      
      @gridsize = 0
      numband.times do |i|
        increment = 2.0 * @r * griddensity * (bands[2*i+1] - bands[2*i])
        @gridsize += increment.round
      end
      @gridsize -= 1 if symmetry == :negative

      taps = Array.new @r+1, 0.0
      @h = Array.new numtaps, 0.0
      @grid = Array.new @gridsize, 0.0
      @d = Array.new @gridsize, 0.0
      @w = Array.new @gridsize, 0.0
      @e = Array.new @gridsize, 0.0
      @ext = Array.new @r+1, 0
      @x = Array.new @r+1, 0.0
      @y = Array.new @r+1, 0.0
      @ad = Array.new @r+1, 0.0
      @foundExt = Array.new @r*2, 0
      
      delf = 0.5/(griddensity*@r)
      if (symmetry == :negative) && (delf > bands[0])
        bands[0] = delf 
      end
      j=0
      numband.times do |band|
        @grid[j] = bands[2*band]
        lowf = bands[2*band]
        highf = bands[2*band + 1]
        ((highf - lowf)/delf).round.times do |i|
          @d[j] = des[band]
          @w[j] = weight[band]
          @grid[j] = lowf
          lowf += delf
          j += 1
        end
        @grid[j-1] = highf
      end
      @grid[@gridsize-1] = 0.5-delf if (
        (symmetry == :negative) &&
        (@grid[@gridsize-1] > (0.5 - delf)) &&
        numtaps.odd?
      )

      (0..@r).each do |i|
        @ext[i] = i * (@gridsize-1) / @r
      end
      
      if type == :differentiator
        @gridsize.times do |i|
          @w[i] = @w[i]/@grid[i] if @d[i] > 0.0001
        end
      end
      
      if symmetry == :positive
        if numtaps.even?
          @gridsize.times do |i|
            c = Math.cos(PI * @grid[i])
            @d[i] /= c
            @w[i] *= c
          end
        end
      else
        if numtaps.odd?
          @gridsize.times do |i|
            c = Math.sin(PI2 * @grid[i])
            @d[i] /= c
            @w[i] *= c
          end
        else
          @gridsize.times do |i|
            c = Math.sin(PI * @grid[i])
            @d[i] /= c
            @w[i] *= c
          end
        end
      end

      if maxiterations > 0
        maxiter_error = true
      else
        maxiterations = -maxiterations
        maxiter_error = false
      end
      iter = 0
      while iter < maxiterations
        calc_params
        calc_error
        search
        break if done?
        iter += 1
      end
      raise "Maximum iterations exceeded" if maxiter_error && iter == maxiterations
      calc_params
      
      (0..numtaps/2).each do |i|
        if symmetry == :positive
          if numtaps.odd?
            c = 1
          else
            c = Math.cos(PI * i / numtaps)
          end
        else
          if numtaps.odd?
            c = Math.sin(PI2 * i / numtaps)
          else
            c = Math.sin(PI * i / numtaps)
          end
        end
        taps[i] = compute_a(i.to_f / numtaps) * c
      end
    
      m = (numtaps.to_f-1)/2
      if symmetry == :positive
        if numtaps.odd?
          (0...numtaps).each do |n|
            val = taps[0]
            x = PI2 * (n - m)/numtaps
            (1..m).each do |k|
              val += 2.0 * taps[k] * Math.cos(x*k)
            end
            @h[n] = val/numtaps
          end
        else
          (0...numtaps).each do |n|
            val = taps[0]
            x = PI2 * (n - m)/numtaps
            (1..numtaps/2-1).each do |k|
              val += 2.0 * taps[k] * Math.cos(x*k)
            end
            @h[n] = val/numtaps
          end
        end
      else
        if numtaps.odd?
          (0...numtaps).each do |n|
            val = 0
            x = PI2 * (n - m)/numtaps
            (1..m).each do |k|
              val += 2.0 * taps[k] * Math.sin(x*k)
            end
            @h[n] = val/numtaps
          end
        else
          (0...numtaps).each do |n|
            val = taps[numtaps/2] * Math.sin(PI * (n - m))
            x = PI2 * (n - m) / numtaps
            (1..numtaps/2-1).each do |k|
              val += 2.0 * taps[k] * Math.sin(x*k)
            end
            @h[n] = val/numtaps
          end
        end
      end
      
      @gridsize = nil
      @r = nil
      @grid = nil
      @d = nil
      @w = nil
      @e = nil
      @ext = nil
      @x = nil
      @y = nil
      @ad = nil
      @foundExt = nil
      @options = nil
      @h.freeze
    end
    
    
    def calc_params
      (0..@r).each do |i|
        @x[i] = Math.cos(PI2 * @grid[@ext[i]])
      end
      ld = (@r-1)/15 + 1
      (0..@r).each do |i|
        denom = 1.0
        xi = @x[i]
        (0...ld).each do |j|
          k=j
          while k <= @r
            denom *= 2.0*(xi - @x[k]) if k != i
            k += ld
          end
        end
        denom = 0.00001 if denom.abs < 0.00001
        @ad[i] = 1.0/denom
      end
      numer = denom = 0
      sign = 1
      (0..@r).each do |i|
        numer += @ad[i] * @d[@ext[i]]
        denom += sign * @ad[i]/@w[@ext[i]]
        sign = -sign
      end
      delta = numer/denom
      sign = 1
      (0..@r).each do |i|
        @y[i] = @d[@ext[i]] - sign * delta / @w[@ext[i]]
        sign = -sign
      end
    end


    def calc_error
      @gridsize.times do |i|
        @e[i] = @w[i] * (@d[i] - compute_a(@grid[i]))
      end
    end
    
    
    def compute_a freq
      denom = numer = 0;
      xc = Math.cos(PI2 * freq)
      (0..@r).each do |i|
        c = xc - @x[i]
        if c.abs < 1.0e-7
          numer = @y[i]
          denom = 1
          break
        end
        c = @ad[i]/c
        denom += c
        numer += c*@y[i]
      end
      numer/denom
    end
    
    
    def search
      @foundExt.fill 0
      k = 0
      if ((@e[0]>0.0) && (@e[0]>@e[1])) || ((@e[0]<0.0) && (@e[0]<@e[1]))
        @foundExt[k] = 0
        k += 1
      end
      (1...@gridsize-1).each do |i|
        if (((@e[i]>=@e[i-1]) && (@e[i]>@e[i+1]) && (@e[i]>0.0)) ||
             ((@e[i]<=@e[i-1]) && (@e[i]<@e[i+1]) && (@e[i]<0.0)))
          @foundExt[k] = i
          k += 1
        end
      end
      j = @gridsize-1
      if (((@e[j]>0.0) && (@e[j]>@e[j-1])) ||
          ((@e[j]<0.0) && (@e[j]<@e[j-1])))
        @foundExt[k] = j
        k += 1
      end
      extra = k - (@r+1)
      while (extra > 0)
        up = @e[@foundExt[0]] > 0.0
        l = 0
        alt = true
        (1...k).each do |j|
          l = j if (@e[@foundExt[j]].abs < @e[@foundExt[l]].abs)
          if up && (@e[@foundExt[j]] < 0.0)
            up = false
          elsif !up && (@e[@foundExt[j]] > 0.0)
            up = true
          else
            alt = false
            break
          end
        end
        if alt && (extra == 1)
          if (@e[@foundExt[k-1]].abs < @e[@foundExt[0]].abs)
            l = @foundExt[k-1]
          else
            l = @foundExt[0]
          end
        end
        (l...k).each do |j|
          @foundExt[j] = @foundExt[j+1]
        end
        k -= 1
        extra -= 1
      end
      (0..@r).each do |i|
        @ext[i] = @foundExt[i]
      end
    end
    
    
    def done?
      min = max = @e[@ext[0]].abs
      (1..@r).each do |i|
        current = @e[@ext[i]].abs
        min = current if current < min
        max = current if current > max
      end
      ((max-min)/max) < 0.0001
    end
   
  end
end
