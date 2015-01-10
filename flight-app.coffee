{CircularInterpolatingSimulator, Simulator, makeRule} = require "./revca_track"
{parseFieldDescriptionlLanguage} = require "./fdl_parser"

# shim layer with setTimeout fallback
unless window.requestAnimationFrame?
  window.requestAnimationFrame =
    window.webkitRequestAnimationFrame or
    window.mozRequestAnimationFrame or
    (callback) -> window.setTimeout(callback, 1000 / 30)


#taken from http://www.html5canvastutorials.com/advanced/html5-canvas-mouse-coordinates/
getCanvasCursorPosition = (e, canvas) ->
  if e.type in ["touchmove", "touchstart", "touchend"]
    e=e.touches[0]
  if e.clientX?
    rect = canvas.getBoundingClientRect()
    return [e.clientX - rect.left, e.clientY - rect.top]


class SimulatorApp
#drawCanvasSimulation
  constructor: ->
    @colors = []
    @canvas = document.getElementById "sim-canvas"
    @ctx = @canvas.getContext "2d"
    
    @size = 8 #will be overwritten anyways

    #doubleRot = "1,2,4,8:rot90; 14,13,10,7:rot270"
    #bounceGas = "1,2,4,8,14,13,10,7:rot180; 9,6:rot90"
    #billiardBallMachine = "1,2,4,8:rot180; 9,6:rot90"
    @rule = makeRule "1,2,4,8:rot90"

    width = 80
    if screen?
      height = Math.floor(screen.height / screen.width * width * 0.9) & ~1 #clear low bit
    else
      height = 60
    
    sim = new Simulator( width, height, @rule)
    
    #s.put [[6, 5],[7,5],[6,7],[7,7], [10,6]]
    @fadeRatio = 0.9
    @bgColor = [0,0,0]
  
    #Interpolated steps between each generations. Only affects kernel size.
    @timeSteps = 100
    @maxStepsPerFrame = 10000 * @timeSteps #don't try to calculate too much per one frame.
    @gensPerSecond = 50
    @lanczosOrder = 3
    @smoothing = 4
    
    @isim = new CircularInterpolatingSimulator sim, @lanczosOrder, @timeSteps, @smoothing
    @bindEvents()
    @playing = false
    @colorPalette = "#fe8f0f #f7325e #7dc410 #fef8cf #0264ed".split(" ")

    @_updateSimSpeed()
    @_updateSmoothing()
    @_updateTrails()
    @_onResize()

    @putRandomPattern()

    @library = new Library
    @library.loadItem = (fdl)=>@_loadFdl(fdl)

    @_updatePlayBtn()
    @_delayedLoadLibrary()
    
  _delayedLoadLibrary: ->
    doLoad = =>
      for item in window.defaultLibrary
        @library.addFdl item, @colorPalette
    window.setTimeout doLoad, 100

  #Just some plausible random initialization  
  putRandomPattern: (numCells, patternSize)->
    s = @isim.simulator
    
    patternSize = Math.min(s.height, s.width)*0.4
    numCells = patternSize**2*0.22 #same as on my test screen
    
    @putPattern (for i in [0...numCells] by 1
      f = Math.random()*2*Math.PI
      r = (Math.random()*2-1) * patternSize
      
      x = Math.round( s.width*0.5 + r*Math.cos(f))
      y = Math.round( s.height*0.5 + r*Math.sin(f))
      [x|0,y|0])
    
  _updateSimSpeed: ->  @gensPerSecond = parseFloat document.getElementById("sim-speed").value
  _updateSmoothing: -> @isim.setSmoothing parseInt document.getElementById("smoothing").value, 10
  _updateTrails: ->    @fadeRatio = parseFloat document.getElementById("trails").value
  _loadFdl: (fdl) ->
    cx = (@isim.simulator.width/2) & ~1
    cy = (@isim.simulator.height/2) & ~1
    try
      parsed = parseFieldDescriptionlLanguage fdl, @colorPalette
      document.getElementById("fld-text").value = fdl
    catch e
      alert "Failed to parse: #{e}"
    @isim.clear()
    if parsed.pattern.length > 0
      @isim.put parsed.pattern, cx, cy
      @colors = parsed.colors
    @isim.simulator.rule = parsed.rule ? makeRule "1,2,4,8:rot90"
    @_updateClearBtnIcon()
    @_clearBackground()
    window.scrollTo 0, 0
    
  clearAll: ->
    @isim.clear()
    @_clearBackground() unless @playing
    @_updateClearBtnIcon()
    
  _updateClearBtnIcon: ->
    clearVisible = @isim.simulator.cells.length isnt 0      
    if @_clearBtnVisibility isnt clearVisible
      @_clearBtnVisibility = clearVisible
      if clearVisible
        document.getElementById("btn-clear").style.display=""
        document.getElementById("btn-random").style.display="none"
      else
        document.getElementById("btn-clear").style.display="none"
        document.getElementById("btn-random").style.display=""
    return
          
  bindEvents: ->
    document.getElementById("sim-speed").addEventListener "change", (e)=>@_updateSimSpeed()
    document.getElementById("smoothing").addEventListener "change", (e)=>@_updateSmoothing()
    document.getElementById("trails").addEventListener "change", (e)=>@_updateTrails()
    
    document.getElementById("btn-clear").addEventListener "click", (e)=>@clearAll()
    document.getElementById("btn-random").addEventListener "click", (e)=>@putRandomPattern()
    document.getElementById("btn-play").addEventListener "click", (e)=>@play() unless @playing
    document.getElementById("btn-pause").addEventListener "click", (e)=>@stop() if @playing
    
    document.getElementById("btn-load-fdl").addEventListener "click", (e)=>
      @_loadFdl document.getElementById("fld-text").value
    window.addEventListener "resize", (e)=> @_onResize()
      
    @canvas.addEventListener "mousedown", (e)=>
      [x,y] = getCanvasCursorPosition e, @canvas
      ix = (x/@size)|0
      iy = (y/@size)|0
      @putCell ix, iy
      @_updateClearBtnIcon()
      e.preventDefault()
      
  _onResize: ->
    container = document.getElementById "main-screen"
    desiredSize = Math.max(1, Math.floor(container.offsetWidth / @isim.simulator.width))|0
    if desiredSize isnt @size
      #console.log "Width: #{container.offsetWidth}, desiredSize: #{desiredSize}"
      @size = desiredSize
      newWidth = @isim.simulator.width * desiredSize
      newHeight = @isim.simulator.height * desiredSize
      @canvas.width = newWidth
      @canvas.height = newHeight
      @_clearBackground()
      unless @playing
        @drawFrame()
        
  _clearBackground: ->
    @ctx.fillStyle = "rgb(#{@bgColor[0]},#{@bgColor[1]},#{@bgColor[2]})"
    @ctx.fillRect 0,0, @canvas.width, @canvas.height      
    
  putCell: (ix, iy, color) ->
    if ix>=0 and ix<@isim.simulator.width and iy>=0 and iy<@isim.simulator.height
      if @isim.putCell ix, iy
        @colors.push (color ? @colorPalette[@colors.length % @colorPalette.length])
        @drawFrame() unless @playing
        @_updateClearBtnIcon()

  #put several cells. Colors is optional
  putPattern: (pattern, colors) ->
    if colors? and (colors.length is 0) then throw new Error("EMpty color palette")
    numCells = @isim.put pattern
    palette = palette ? @colorPalette
    for i in [0...numCells]
      @colors.push palette[@colors.length % palette.length]
    @drawFrame() unless @playing
    @_updateClearBtnIcon()
    return
  drawFrame: ->
    #console.log "Drawing frame"
    xys = @isim.getInterpolatedState()
    #clear the viewport
    #ctx.clearRect 0, 0, ctx.canvas.width, ctx.canvas.height
    ctx = @ctx
    ctx.fillStyle = "rgba(#{@bgColor[0]}, #{@bgColor[1]}, #{@bgColor[2]}, #{@fadeRatio})"
    ctx.fillRect 0,0, ctx.canvas.width, ctx.canvas.height

    ctx.lineWidth = 1
    ctx.strokeStyle = '#003300'
    size = @size
    for i in [0...xys.length] by 2
      x = xys[i]
      y = xys[i+1]
      
      ctx.beginPath()
      ctx.arc x*size, y*size, size/2, 0, 2 * Math.PI, false
      ctx.fillStyle = @colors[i/2]
      ctx.fill()
      #ctx.stroke()
    return


  togglePlay: ->
    if @playing
      @stop()
    else
      @play()
      
  _updatePlayBtn: ->
    document.getElementById("btn-play").style.display = if @playing then "none" else ""
    document.getElementById("btn-pause").style.display = if @playing then "" else "none"
      
  stop: ->
    @playing = false
    @_updatePlayBtn()
    
  play: ->
    if @playing
      console.log "Already playing"
    else
      console.log "Play"
      
    previousFrameTime = null
    stepsLeft = 1
    @playing = true
    @_updatePlayBtn()
    
    drawFunc = =>
      unless @playing
        console.log "This is: #{this}"
        console.log "Stopping"
        return
      timeNow = Date.now()
      unless previousFrameTime
        previousFrameTime = timeNow

      #milliseconds after the last frame
      delta = timeNow - previousFrameTime
      previousFrameTime = timeNow
      
      steps = delta * @gensPerSecond *0.001 * @timeSteps + stepsLeft
      
      #Move to the next step, but don't try bove by more than 1000.
      iSteps = Math.round steps

      #console.log "Steps: #{iSteps}"
      @drawFrame() if iSteps > 0
      
      @isim.nextTime Math.min( @maxStepsPerFrame, iSteps )
      stepsLeft = steps - iSteps
      window.requestAnimationFrame drawFunc

    drawFunc()

class Library
  constructor: ->
    @list = document.getElementById "library"
    @loadItem = null
    @iconSize = [64, 56]

  addFdl: (fdl, palette)->
    {pattern, colors, name} = parseFieldDescriptionlLanguage fdl, palette
    liItem = document.createElement "li"
    liItem.setAttribute "data-fdl", fdl
    liAnchor = document.createElement "a"
    liAnchor.setAttribute "href", "#"
    liItem.appendChild liAnchor
    
    canvasContainer = document.createElement "div"
    canvasContainer.setAttribute "class", "library-icon"
    
    itemImage = document.createElement "canvas"
    [itemImage.width, itemImage.height]  =  @iconSize
    
    canvasContainer.appendChild itemImage
    liAnchor.appendChild canvasContainer
    
    descText = document.createTextNode name
    liAnchor.appendChild descText
    @drawPatternOn pattern, colors, itemImage
    
    @list.appendChild liItem
    
    liAnchor.addEventListener "click", (e)=>
      @loadItem fdl if @loadItem?
      e.preventDefault()
    return
    
  drawPatternOn: (pattern, colors, canvas)->
    ctx = canvas.getContext "2d"
    unless ctx? then throw new Error "Not a canvas!"
    w = canvas.width
    h = canvas.height
    ctx.fillStyle = "#000"
    ctx.fillRect 0,0,w,h
    
    [x0,y0,x1,y1] = patternBounds pattern
    iw = x1-x0+1
    ih = y1-y0+1
    r = Math.max(2, Math.min(w/iw, h/ih))|0
    for [x,y],i in pattern
      ix = ((x - x0 - iw/2 + 0.5) * r + w/2)|0
      iy = ((y - y0 - ih/2 + 0.5) * r + h/2)|0
      
      ctx.beginPath()
      ctx.arc ix, iy, r/2, 0, 2 * Math.PI, false
      ctx.fillStyle = colors[i] ? "blue"
      ctx.fill()
      
    return
        
  _itemClick: (fdl)-> 

patternBounds = (lst) ->
  return [0, 0, 0, 0]  if lst.length is 0
  [x1, y1] = [x0, y0] = lst[0]
  for i in [1 ... lst.length] by 1
    [x,y] = lst[i]
    x0 = Math.min(x0, x)
    x1 = Math.max(x1, x)
    y0 = Math.min(y0, y)
    y1 = Math.max(y1, y)
  [x0, y0, x1, y1]
            
#drawCanvasSimulation
window.runCanvasSimulation = ->
  app = new SimulatorApp()
  app.play()

  
