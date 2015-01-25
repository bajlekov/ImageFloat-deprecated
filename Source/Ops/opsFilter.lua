--[[
	Copyright (C) 2011-2014 G. Bajlekov

    ImageFloat is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ImageFloat is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local filter = {}

do
  local ffi = require("ffi")
  local pix = ffi.new("float[9]")
  local A = ffi.new("int[19]", 1,4,7,0,3,6,1,4,7,0,5,4,3,1,2,4,4,6,4)
  local B = ffi.new("int[19]", 2,5,8,1,4,7,2,5,8,3,8,7,6,4,5,7,2,4,2)
  
  local function sort(a, b)
    if pix[a]>pix[b] then
      pix[a], pix[b] = pix[b], pix[a]
    end
  end

  function filter.median()
    local s = __global.state
    local b = __global.buf
    local p = __global.params
    local progress  = __global.progress
    local inst    = __global.instance
    local instmax = __global.instmax
    
    for x = inst+1, s.xmax-2, instmax do
      if progress[instmax]==-1 then break end
      for y = 1, s.ymax-2 do
        
        for c = 0, s.zmax-1 do
          pix[0], pix[1], pix[2] = b[1]:getxy(c,x-1,y-1), b[1]:getxy(c,x,y-1), b[1]:getxy(c,x+1,y-1)
          pix[3], pix[4], pix[5] = b[1]:getxy(c,x-1,y),   b[1]:getxy(c,x,y),   b[1]:getxy(c,x+1,y)
          pix[6], pix[7], pix[8] = b[1]:getxy(c,x-1,y+1), b[1]:getxy(c,x,y+1), b[1]:getxy(c,x+1,y+1)
          for i = 0, 18 do
            sort(A[i], B[i]);
          end
          b[2]:setxy(pix[4], c, x, y)
        end
        
      end
      progress[inst] = x - inst
    end
    progress[inst] = -1
  end

end

--TODO: rank-conditioned rank-selection

function filter.mean()
    local s = __global.state
    local b = __global.buf
    local p = __global.params
    local progress  = __global.progress
    local inst    = __global.instance
    local instmax = __global.instmax
    
    for x = inst+1, s.xmax-2, instmax do
      if progress[instmax]==-1 then break end
      for y = 1, s.ymax-2 do
        
        for c = 0, s.zmax-1 do
          local v =
          b[1]:getxy(c,x-1,y-1) + b[1]:getxy(c,x,y-1) + b[1]:getxy(c,x+1,y-1) +
          b[1]:getxy(c,x-1,y)   + b[1]:getxy(c,x,y)   + b[1]:getxy(c,x+1,y) +
          b[1]:getxy(c,x-1,y+1) + b[1]:getxy(c,x,y+1) + b[1]:getxy(c,x+1,y+1)
          b[2]:setxy(v/9, c, x, y)
        end
        
      end
      progress[inst] = x - inst
    end
    progress[inst] = -1
  end

-- midpoint: (max-min)/2 + min
-- clip between min and max
-- truncate (0-1)
-- threshold (soft/hard)
function filter.threshold()
  local s = __global.state
  local b = __global.buf
  local p = __global.params
  local progress  = __global.progress
  local inst    = __global.instance
  local instmax = __global.instmax
  
  for x = inst, s.xmax-2, instmax do
    if progress[instmax]==-1 then break end
    for y = 0, s.ymax-1 do
      
      for c = 0, s.zmax-1 do
        local v = b[1]:getxy(c,x,y) >= b[2]:getxy(c,x,y) and 1 or 0 
        b[3]:setxy(v, c, x, y)
      end
      
    end
    progress[inst] = x - inst
  end
  progress[inst] = -1
end


function filter.max()
  local s = __global.state
  local b = __global.buf
  local p = __global.params
  local progress  = __global.progress
  local inst    = __global.instance
  local instmax = __global.instmax
  
  for x = inst+1, s.xmax-2, instmax do
    if progress[instmax]==-1 then break end
    for y = 1, s.ymax-2 do
      
      for c = 0, s.zmax-1 do
        local v = math.max(
        b[1]:getxy(c,x-1,y-1), b[1]:getxy(c,x,y-1), b[1]:getxy(c,x+1,y-1),
        b[1]:getxy(c,x-1,y),   b[1]:getxy(c,x,y),   b[1]:getxy(c,x+1,y),
        b[1]:getxy(c,x-1,y+1), b[1]:getxy(c,x,y+1), b[1]:getxy(c,x+1,y+1)
        )
        b[2]:setxy(v, c, x, y)
      end
      
    end
    progress[inst] = x - inst
  end
  progress[inst] = -1
end
  
function filter.min()
  local s = __global.state
  local b = __global.buf
  local p = __global.params
  local progress  = __global.progress
  local inst    = __global.instance
  local instmax = __global.instmax
  
  for x = inst+1, s.xmax-2, instmax do
    if progress[instmax]==-1 then break end
    for y = 1, s.ymax-2 do
      
      for c = 0, s.zmax-1 do
        local v = math.min(
        b[1]:getxy(c,x-1,y-1), b[1]:getxy(c,x,y-1), b[1]:getxy(c,x+1,y-1),
        b[1]:getxy(c,x-1,y),   b[1]:getxy(c,x,y),   b[1]:getxy(c,x+1,y),
        b[1]:getxy(c,x-1,y+1), b[1]:getxy(c,x,y+1), b[1]:getxy(c,x+1,y+1)
        )
        b[2]:setxy(v, c, x, y)
      end
      
    end
    progress[inst] = x - inst
  end
  progress[inst] = -1
end

function filter.diffx()
  local s = __global.state
  local b = __global.buf
  local p = __global.params
  local progress  = __global.progress
  local inst    = __global.instance
  local instmax = __global.instmax
  
  for x = inst, s.xmax-2, instmax do
    if progress[instmax]==-1 then break end
    for y = 0, s.ymax-1 do
      
      for c = 0, s.zmax-1 do
        local v = b[1]:getxy(c,x,y) - b[1]:getxy(c,x+1,y)
        b[2]:setxy(v, c, x, y)
      end
      
    end
    progress[inst] = x - inst
  end
  progress[inst] = -1
end

function filter.diffy()
  local s = __global.state
  local b = __global.buf
  local p = __global.params
  local progress  = __global.progress
  local inst    = __global.instance
  local instmax = __global.instmax
  
  for x = inst, s.xmax-1, instmax do
    if progress[instmax]==-1 then break end
    for y = 0, s.ymax-2 do
      
      for c = 0, s.zmax-1 do
        local v = b[1]:getxy(c,x,y) - b[1]:getxy(c,x,y+1)
        b[2]:setxy(v, c, x, y)
      end
      
    end
    progress[inst] = x - inst
  end
  progress[inst] = -1
end

function filter.roberts()
  local s = __global.state
  local b = __global.buf
  local p = __global.params
  local progress  = __global.progress
  local inst    = __global.instance
  local instmax = __global.instmax
  
  for x = inst, s.xmax-2, instmax do
    if progress[instmax]==-1 then break end
    for y = 0, s.ymax-2 do
      
      for c = 0, s.zmax-1 do
        local v = math.abs(b[1]:getxy(c,x,y) - b[1]:getxy(c,x+1,y+1)) +
          math.abs(b[1]:getxy(c,x,y+1) - b[1]:getxy(c,x+1,y)) 
        b[2]:setxy(v, c, x, y)
      end
      
    end
    progress[inst] = x - inst
  end
  progress[inst] = -1
end

function filter.prewitt()
  local s = __global.state
  local b = __global.buf
  local p = __global.params
  local progress  = __global.progress
  local inst    = __global.instance
  local instmax = __global.instmax
  
  for x = inst+1, s.xmax-2, instmax do
    if progress[instmax]==-1 then break end
    for y = 1, s.ymax-2 do
      
      for c = 0, s.zmax-1 do
        local vx = b[1]:getxy(c,x+1,y-1) + b[1]:getxy(c,x+1,y) + b[1]:getxy(c,x+1,y+1) -
            (b[1]:getxy(c,x-1,y-1) + b[1]:getxy(c,x-1,y) + b[1]:getxy(c,x-1,y+1))
        local vy = b[1]:getxy(c,x-1,y+1) + b[1]:getxy(c,x,y+1) + b[1]:getxy(c,x+1,y+1) -
            (b[1]:getxy(c,x-1,y-1) + b[1]:getxy(c,x,y-1) + b[1]:getxy(c,x+1,y-1))
        b[2]:setxy(math.sqrt(vx^2+vy^2), c, x, y)
      end
      
    end
    progress[inst] = x - inst
  end
  progress[inst] = -1
end

function filter.sobel()
  local s = __global.state
  local b = __global.buf
  local p = __global.params
  local progress  = __global.progress
  local inst    = __global.instance
  local instmax = __global.instmax
  
  for x = inst+1, s.xmax-2, instmax do
    if progress[instmax]==-1 then break end
    for y = 1, s.ymax-2 do
      
      for c = 0, s.zmax-1 do
        local vx = b[1]:getxy(c,x+1,y-1) + 2*b[1]:getxy(c,x+1,y) + b[1]:getxy(c,x+1,y+1) -
            (b[1]:getxy(c,x-1,y-1) + 2*b[1]:getxy(c,x-1,y) + b[1]:getxy(c,x-1,y+1))
        local vy = b[1]:getxy(c,x-1,y+1) + 2*b[1]:getxy(c,x,y+1) + b[1]:getxy(c,x+1,y+1) -
            (b[1]:getxy(c,x-1,y-1) + 2*b[1]:getxy(c,x,y-1) + b[1]:getxy(c,x+1,y-1))
        b[2]:setxy(math.abs(vx)+math.abs(vy), c, x, y)
      end
      
    end
    progress[inst] = x - inst
  end
  progress[inst] = -1
end

function filter.angle()
  local s = __global.state
  local b = __global.buf
  local p = __global.params
  local progress  = __global.progress
  local inst    = __global.instance
  local instmax = __global.instmax
  
  for x = inst, s.xmax-1, instmax do
    if progress[instmax]==-1 then break end
    for y = 0, s.ymax-2 do
      
      for c = 0, s.zmax-1 do
        local vx, vy = b[1]:getxy(c,x,y), b[2]:getxy(c,x,y)
        b[3]:setxy(math.sqrt(vx^2+vy^2), c, x, y)
        b[4]:setxy(math.atan2(vy, vx)/2/math.pi+0.5, c, x, y)
      end
      
    end
    progress[inst] = x - inst
  end
  progress[inst] = -1
end

--[[
 TODO:
 
 separate filters in:
 - kernel
 - angle
 - magnitude
 - angle
--]]

return filter