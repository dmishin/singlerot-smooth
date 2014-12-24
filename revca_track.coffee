#!/usr/bin/env coffee

mod2 = (x) -> x & 1

mod = (x, y) ->
  m = x % y
  if (m < 0) then (m + y) else m
snap = (x, t) ->
  #(x +t ) - mod2(x+t) - t
  x - mod2(x+t)

#Rule string format: "n1,n1,n3:rot90; n4,n5,n6:rot180; ..."
# singleRotate: "1,2,4,8: rot90
# 
exports.makeRule = makeRule = ( ruleString ) ->
  rule = {}
  for part in ruleString.split ";"
    codes2tfm = part.split ":"
    if codes2tfm.length isnt 2 then throw new Error "Parse error: #{part} must have form n1,n2,...:tfm"
    [codes, tfmName] = codes2tfm
    tfm = Transforms[tfmName.trim()]
    if not tfm? then throw new Error "Parse error: unknown transform #{tfmName}"
    for code in codes.split ","
      iCode = parseInt code.trim(), 10
      unless iCode in [0..15] then throw new Error "Error: code must be in range 0..15"
      if rule[iCode]? then throw new Error "Error: code #{iCode} ("#{code}") specified twice"
      rule[iCode] = tfm
  return rule 

# Misc transformations. These names are used by makeRule function.
Transforms = 
  rot90:  (dx, dy)-> [-dy, dx]
  rot180: (dx, dy)-> [-dx, -dy]
  rot270: (dx, dy)-> [dy, -dx]
  flipX:  (dx, dy)-> [-dx, dy]
  flipY:  (dx, dy)-> [dx, -dy]
  flipDiag:  (dx, dy)-> [dy, dx]
  flipADiag: (dx, dy)-> [-dy, -dx]

fillZeros = (arr) ->
  for i in [0...arr.length] by 1
    arr[i] = 0
  return arr
  
newInt8Array = if Int8Array?
    (sz) -> new Int8Array sz
  else
    (sz) -> fillZeros new Array sz
    
newFloatArray = if Float32Array?
    (sz) -> new Float32Array sz
  else
    (sz) -> fillZeros new Array sz

exports.Simulator = class Simulator
  constructor: (@width, @height, rule)->
    @cells = []
    #values are indices of cells array + 1
    @field = newInt8Array @width*@height
    @field1 = newInt8Array @width*@height
    @phase = 0
    @rule = rule ? {1: Transforms.rot90, 2: Transforms.rot90, 4:Transforms.rot90, 8:Transforms.rot90}
    
  cellCount: -> (@cells.length/2) | 0

  #index of a cell
  index: (x,y) -> x+y*@width
  
  #wrapped index
  indexw: (x,y) -> @index mod(x,@width), mod(y,@height)
  #add new cell if not present yet  
  putCell: (x,y) ->
    idx = @index x, y    
    if @field[idx] is 0
      c = @cells
      c.push x
      c.push y
      @field[idx] = 1
      c.length - 1
    else
      null
  #add many cells
  put: (pattern,x0=0,y0=0)->
    for [x,y] in pattern
      @putCell x+x0, y+y0
    return
  #get cells
  getCells: ->
    cc= @cells
    for i in [0...cc.length] by 2
      [cc[i], cc[i+1]]
  clear: ->
    @cells = []
    @phase = 0
    @field = newInt8Array @width*@height
    return 
  #Binary code of the 2x2 block, 0 to 15
  blockCode: (x, y) ->
    f = @field
    (f[@indexw(x,y)]) * 1 +\
    (f[@indexw(x+1,y)]) * 2 +\
    (f[@indexw(x,y+1)]) * 4 +\
    (f[@indexw(x+1,y+1)]) * 8

  #Simulate for one step
  step: ->
    phase = @phase
    nextCells = []

    field1 = @field1
    for i in [0 ... @field1.length] by 1
      field1[i] = 0
    
    for i in [0...@cells.length] by 2
      x = @cells[i]
      y = @cells[i+1]
      x0 = snap x, phase
      y0 = snap y, phase
      tfm = @rule[@blockCode(x0, y0)]
      if tfm?
        [dx,dy] = tfm x-x0-0.5, y-y0-0.5
        x1 = mod ((x0+0.5+dx)|0), @width
        y1 = mod ((y0+0.5+dy)|0), @height
      else
        x1 = x
        y1 = y
      @field1[@index x1, y1] = 1
      nextCells.push x1
      nextCells.push y1
    [@field1, @field] = [@field, @field1]
    @phase = @phase ^ 1
    oldCells = @cells
    @cells = nextCells
    return oldCells
    

  
sinc = (x) ->
  if Math.abs(x) > 1e-8
    Math.sin(x)/x
  else
    #sin x ~~ x - x^3/6
    #sinc x ~~ 1 - x^2/6
    1 - x*x/6
    
#make lanczosh kernel. n points per unit interval, kernel order is a
lanczosKernel = (a, n) ->
  #in total, 2a*n+1 points
  # a is integer
  if a isnt a|0
    throw new Error "A must be integer"
    
  for ix in [-a*n .. a*n] by 1
    x = ix / n * Math.PI
    sinc(x)*sinc(x/a)

#Returns interpolator function and the maximal number of states it requires
# if downscale=1, then pure interpolation is done.
#              2, then smoothing is done.
# the bigger downscale is, the more higher frequencies are smoothed
lanczosInterpolator = (a, n, downscale=1) ->
  kernel = lanczosKernel a, n*downscale
  #console.log "kr = np.array(#{JSON.stringify kernel})"
  #throw new Error "stop"
  interpolate = ( states, offset )->
    if offset >= n or offset < 0
      throw new Error "Incorrect offset, must be in [0; #{n}) "
    sum = newFloatArray states[0].length
    for state, i in states
      idx = i * n + offset
      break if idx >= kernel.length
      addScaled sum, state, kernel[idx]
      #console.log "####      adding state #{i} with k=#{kernel[idx]} (idx=#{idx})"
    return sum
  maxNumStates = 2*a*downscale
  return [interpolate, maxNumStates]
  
# a + b*k  
addScaled = (a, b, k)->
  for bi, i in b
    a[i]+= bi*k
  return a
  
exports.CircularInterpolatingSimulator = class CircularInterpolatingSimulator
  constructor: (@simulator, order, @timeSteps, @smoothing=1) ->
    @order = order * smoothing
    [@interpolator, @neededStates] = lanczosInterpolator @order, @timeSteps, @smoothing
    
    @states = []
    @_fillBuffer()
    @time = 0
    
  setSmoothing: (newSmoothing) ->
    return if newSmoothing is @smoothing
    @smoothing = newSmoothing
    [@interpolator, @neededStates] = lanczosInterpolator @order, @timeSteps, newSmoothing
    @_fillBuffer()

  put: (pattern) ->
    newStates = []
    for [x,y] in pattern
      if @simulator.putCell(x,y)?
        newStates.push x
        newStates.push y
    @_appendStateToBuffer @_mapState newStates
    return newStates.length
    
  putCell: (xy...) -> @put [xy]
      
  clear: ->
    @simulator.clear()
    @states = ([] for i in [0 ... @neededStates])
    return
    
  _appendStateToBuffer:
    if Float32Array?
      (tail) ->
        @states = for state in @states
          newState = newFloatArray(state.length + tail.length)
          newState.set state
          newState.set tail, state.length
          newState
        return
    else
      (tail) ->
        @states = for state in @states
          state.concat tail
        return
        
    
    
  _getState: -> @_mapState @simulator.step()
  
  _mapState: (s) ->
    s1 = newFloatArray s.length*2
    iw = 2 * Math.PI / @simulator.width
    ih = 2 * Math.PI / @simulator.height
    for i in [0...s.length] by 2
      j = i*2
      nx = s[i]*iw
      s1[j] = Math.cos nx
      s1[j+1] = Math.sin nx
      ny = s[i+1]*ih
      s1[j+2]= Math.cos ny
      s1[j+3]= Math.sin ny
    return s1
    
  _unMapState: (s) ->
    kx = @simulator.width / (2*Math.PI)
    ky = @simulator.height / (2*Math.PI)
    PI2 = Math.PI*2
    wrapPi = (x) -> if x > 0 then x else x + PI2
    s1 = newFloatArray s.length/2
    for i in [0..s.length] by 4
      j = (i/2) |0
      cx = s[i]
      sx = s[i+1]
      cy = s[i+2]
      sy = s[i+3]
      s1[j] = wrapPi(Math.atan2(sx, cx))*kx
      s1[j+1] = wrapPi(Math.atan2(sy, cy))*ky
    return s1

  #Pull enough states to fill the buffer
  _fillBuffer: ->
    if @states.length > @neededStates
      @states = @states[(@states.length-@neededStates)...(@states.length)]
    else
      while @states.length < @neededStates
        @states.push @_getState()
    return
    
  getInterpolatedState: ->
    @_unMapState @interpolator @states, (@timeSteps - @time - 1)
  
  nextTime: (dt) ->
    @time += dt
    while @time >= @timeSteps
      @time -= @timeSteps
      @states = @states[1..]
      @states.push @_getState()
      #console.log "New state acquired"
    return @time
