{parseFieldDescriptionlLanguage} = require "../fdl_parser"
{parseUri} = require "../parseuri"
container = undefined
stats = undefined
camera = undefined
scene = undefined
renderer = undefined
controls = undefined
curves = undefined    
stepsPerMs = 10 / 1000

visibilityDistance = 10000

#Parameter of the splitted processing of tube packs: minimal time between adding separte groups of tubes.
# When time is big, tubes are added by big portions, which is fast, but animation becomes jerky.
# When too slow, tubes could lag.
minTimePerTube = 1000/30 #100 parts/second

palette = [0xfe8f0f, 0xf7325e, 0x7dc410, 0xfef8cf, 0x0264ed]

requestStop = false


class WorkerFlyingCurves
  constructor: (startZ=4000, endZ=-4000) ->
    @worker = new Worker "./tubing_worker_app.js"
    @worker.addEventListener "message", (e)=>@_onMsg(e)
    @worker.addEventListener "error", (e)->
      console.log JSON.stringify e
    
    @scale = scale = 30
    @group = new THREE.Object3D
    @chunks = []
    @zMin = endZ / scale
    @zMax = startZ / scale
    @lastChunkZ = 0

    @group.scale.set scale, scale, scale
    @ready = false
    @taskId2dummyChunks = {}
    @nextTaskId = 0

    #All these parameters are applied, when initializing worker.
    #  (loadPattern)
    #number of steps in one mesh chunk
    @chunkSize = 500
    #generate tube section every nth step (1 - every step)
    @skipSteps = 1
    #size of the toroidal board, must be even!
    @boardSize = 100
    #interpolation order. 1 ... 3. 1 - linear interp, 3 - smooth interp
    @lanczosOrder = 3
    #how many mesh steps are there between 2 generation. integer, 1 ... 4
    @interpSteps = 1
    #Low-pass filter, removed oscillations with period bigger than this.
    # integer, 1 ... 100. 1 - no filtering.
    @smoothingPeriod = 4
    #"speed of light". z-axis length of one generation
    @timeScale = 0.1
    #Radius of a single rube
    @tubeRadius = 0.1
    #NUmber of sides in the tube (2...10)
    @tubeSides = 3
    #continue initialization after loading
        
  _finishInitialize: (nCells, fldWidth, fldHeight, chunkLen)->
    #Colors array must be set by the previous calls
    if @colors.length isnt nCells
      @colors = (palette[i%palette.length] for i in [0...nCells] by 1)
          
    @materials = for color in @colors
      new THREE.MeshBasicMaterial color: color

    @group.position.set -0.5*fldWidth*@scale, -0.5*fldHeight*@scale, 0
    @group.updateMatrix()
    @ready = true
    @chunkLen = chunkLen
    console.log "Initializatoin finished"

  #Calculate geometric size (width, height) of the cross-section of the field.
  getCrossSectionSize: ->
    s = @boardSize * @scale
    [s,s]
    
  _onMsg: (e)->
    cmd = e.data.cmd
    unless cmd?
      console.log "Bad message received! #{JSON.stringify e.data}"
      return
    switch cmd
      when "init"
        @_finishInitialize e.data.nCells, e.data.fldWidth, e.data.fldHeight, e.data.chunkLen
      when "chunk"
        @_receiveChunk e.data.blueprint, e.data.taskId
      else
        console.log "Unknown responce #{e.cmd}"

  #returns: tuple [chunk, taskId]
  # chunk is an empty object
  # taskId is ID of the sent task
  requestChunk: ->
    taskId = @nextTaskId
    @nextTaskId = (taskId + 1) % 65536 #just because.
    @worker.postMessage
      cmd: "chunk"
      taskId: taskId
    dummy = new THREE.Object3D
    @taskId2dummyChunks[taskId] = dummy
    return dummy
    
  _receiveChunk: (blueprint, taskId)->
    chunk = @taskId2dummyChunks[taskId]
    #discard unexpected chunks
    return unless chunk?    
    delete @taskId2dummyChunks[taskId]
    i = 0

    #We must process all tubes in 75% of the chunk flyby time
    chunkFlybyTime = @chunkLen / stepsPerMs

    #How many pieces to split blueprint to
    completionTime = Math.min(1000, chunkFlybyTime * 0.75)
    nPieces = completionTime/minTimePerTube | 0
    nPieces = Math.min(nPieces, blueprint.length)

    tubesPerPart = Math.ceil(blueprint.length / nPieces) | 0
    nPieces = Math.ceil(blueprint.length / tubesPerPart) | 0
    processingDelay = completionTime / nPieces

    timeStart = Date.now()

    processPart = =>
      if i + tubesPerPart < blueprint.length
        setTimeout processPart, processingDelay

      for j in [0...Math.min(blueprint.length-i, tubesPerPart)] by 1
        tubeBp = blueprint[i]
        tubeGeom = @createTube tubeBp
        tube = new THREE.Mesh tubeGeom, @materials[i]
        chunk.add tube
        i+=1
        
      #if i < blueprint.length-1
      #  setTimeout processPart, processingDelay
      #else
      #  dt = Date.now() - timeStart
      #  console.log "Expected completion time: #{completionTime}, actual: #{dt}"
        
    processPart()
    #console.log "Received chunk!"
    return
    
  createTube: (blueprint)->
    tube = new THREE.BufferGeometry()
    
    tube.addAttribute 'position', new THREE.BufferAttribute(blueprint.v, 3)
    tube.addAttribute 'index', new THREE.BufferAttribute(blueprint.idx, 1)
    tube.computeBoundingSphere() #do we need it?
    return  tube

  #remove all tubes, return to the initial state.
  reset: ->
    #we don't expect any more chunks
    @taskId2dummyChunks = {}
    @lastChunkZ = 0
    for chunk in @chunks
      @group.remove chunk
    return

  loadFDL: (fdlText) ->
    parsed = parseFieldDescriptionlLanguage fdlText, palette
    @loadPattern parsed.pattern, parsed.colors
    
  loadPattern: (pattern, colors) ->
    @reset()
    @colors = colors
    @worker.postMessage
      cmd: "init"
      pattern: pattern
      chunkSize: @chunkSize
      skipSteps: @skipSteps #1
      size: @boardSize #100
      lanczosOrder: @lanczosOrder
      interpSteps: @interpSteps
      smoothingPeriod: @smoothingPeriod
      timeScale: @timeScale #0.1
      tubeRadius: @tubeRadius #0.1
      tubeSides: @tubeSides
      # _finishInitialize invoked on responce
    
  step: (dz) ->
    unless @ready
      #console.log "Worker not ready yet..."
      return
      
    i = 0
    while i < @chunks.length
      chunk = @chunks[i]
      chunk.position.setZ chunk.position.z-dz
      if chunk.position.z < @zMin
        #console.log "Discarding chunk #{i}"
        @chunks.splice i, 1
        @group.remove chunk
      else
        i += 1
        
    @lastChunkZ -= dz
    if @lastChunkZ < @zMax
      #console.log "last chunk is at #{@lastChunkZ}, Requesting new chunk..."
      #Posts request to the worker and quickly returns dummy
      chunk = @requestChunk()
      @lastChunkZ += @chunkLen
      chunk.position.setZ @lastChunkZ
      @chunks.push chunk
      @group.add chunk
    return
    
  createIsochronePlane: (z=0, textureScale=8) ->
    #calculate plane dimensions
    [w, h] = @getCrossSectionSize()
    w2 = w*0.5
    h2 = h*0.5
    
    vs = new Float32Array [ 
      -w2, h2,0,
      -w2,-h2,0,
       w2, h2,0,
      -w2,-h2,0,
       w2,-h2,0,
       w2, h2,0
    ]

    tw=th=@boardSize / textureScale
    uvs = new Float32Array [
      0,th, 0,0, tw,th,
      0,0, tw,0, tw,th
    ]
    
      
    plane = new THREE.BufferGeometry()
    plane.addAttribute 'position', new THREE.BufferAttribute(vs, 3)
    plane.addAttribute "uv", new THREE.BufferAttribute(uvs, 2)
    plane.computeBoundingSphere() #do we need it?
    
    texture = THREE.ImageUtils.loadTexture( "../images/isoplane.png" )
    texture.wrapS = THREE.RepeatWrapping
    texture.wrapT = THREE.RepeatWrapping
    
    material = new THREE.MeshBasicMaterial
      map: texture
      side: THREE.DoubleSide
      opacity: 0.5
      transparent: true

    planeMesh = new THREE.Mesh plane, material
    planeMesh.position.setZ z
    @isochrone = planeMesh
  #Load parameters from URI arguments
  loadUriParameters: (keys)->
    loadIntParam = (fieldName, keyName, isValid)=>
      if keyName of keys
        val = parseInt keys[keyName], 10
        if val isnt val
          alert "Value incorrect #{val}"
          return
        if isValid and not isValid(val)
          alert "Parameter #{keyName} is incorrect"
          return
        this[fieldName] = val
        #console.log "Loading paramter #{fieldName}, #{val}"
      return
    loadIntParam "chunkSize", "chunkSize", (s)->(s>=10 and s<100000)
    loadIntParam "skipSteps", "skipSteps", (s)->(s>=1 and s<10000)
    loadIntParam "boardSize", "boardSize", (s)->(s>0 and (s%2 is 0))
    loadIntParam "lanczosOrder", "lanczosOrder", (s)->(s>=0 and s < 10)
    loadIntParam "interpSteps", "interpSteps", (s)->(s>=1 and s <100)
    loadIntParam "smoothingPeriod", "smoothingPeriod", (s)->(s>=1 and s <10000)
    loadIntParam "tubeSides", "tubeSides", (s)->(s>=2 and s <10)
    if "timeScale" of keys
      v = parseFloat keys["timeScale"]
      @timeScale = v if (v is v) and v > 0
    if "tubeRadius" of keys
      v = parseFloat keys["tubeRadius"]
      @tubeRadius = v if (v is v) and v > 0
    return
          

                                              
init = ->
  keys = parseUri(window.location).queryKey
  container = document.getElementById("container")

  if keys.visibility?
    vd = parseFloat keys.visibility
    if vd > 0 and vd < 1e5
      visibilityDistance=vd
  #
  camera = new THREE.PerspectiveCamera(27, window.innerWidth / window.innerHeight, 1, visibilityDistance * 1.1)
  camera.position.set 300, 0, -1550
  scene = new THREE.Scene()
  scene.fog = new THREE.Fog 0x000505, visibilityDistance*0.85, visibilityDistance
  scene.add new THREE.AmbientLight 0x444444 

  controls = new THREE.TrackballControls  camera

  controls.rotateSpeed = 1.0
  controls.zoomSpeed = 3.2
  controls.panSpeed = 0.8

  controls.noZoom = false
  controls.noPan = false

  controls.staticMoving = true
  controls.dynamicDampingFactor = 0.9

  controls.keys = [ 65, 83, 68 ]

  curves = new WorkerFlyingCurves visibilityDistance, -0.5*visibilityDistance
  #apply additional parameters
  curves.loadUriParameters keys
      
  loadRandomPattern Math.min(20, Math.round(curves.boardSize*0.4))
  
  scene.add curves.group
  scene.add curves.createIsochronePlane 1000
  
  #
  renderer = new THREE.WebGLRenderer(antialias: keys.antialias is "true")
  renderer.setSize window.innerWidth, window.innerHeight
  renderer.gammaInput = true
  renderer.gammaOutput = true
  container.appendChild renderer.domElement
  
  #
  if Stats?
    stats = new Stats()
    stats.domElement.style.position = "absolute"
    stats.domElement.style.bottom = "0px"
    container.appendChild stats.domElement
  
  #
  window.addEventListener "resize", onWindowResize, false
  return
  
onWindowResize = ->
  camera.aspect = window.innerWidth / window.innerHeight
  camera.updateProjectionMatrix()
  renderer.setSize window.innerWidth, window.innerHeight
  controls.handleResize()
  return
  
showPatternsWindow = ->
  controls.enabled = false
  patterns = document.getElementById "patterns-window"  
  patterns.style.display = "" #reset "none" and apply setting from css

hidePatternsWindow = ->
  controls.enabled = true
  patterns = document.getElementById "patterns-window"  
  patterns.style.display = "none"#override CSS and hide.

loadRandomPattern = (size) ->
  curves.loadPattern makeRandomPattern(size)...
  
makeRandomPattern = (size) ->
  cells = {}
  pattern = []
  colors = []
  xyRange = Math.sqrt(size)
  while pattern.length isnt size
    #Generate normally distributed cells, using box-muller transform.
    #I just want to implement it.
    u1 = Math.random()*Math.PI
    u2 = Math.random()
    r = Math.sqrt(-Math.log(u2))*xyRange
    if r>100 or r isnt r then continue
    x = Math.round(Math.cos(u1)*r) |0
    y = Math.round(Math.sin(u1)*r) |0
    key = "#{x}$#{y}"
    if key of cells then continue
    cells[key] = true
    pattern.push [x,y]
    colors.push palette[pattern.length % palette.length]
  return [pattern, colors]
    
loadCustomPattern = ->
  try
    curves.loadFDL document.getElementById("custom-rle").value
    true
  catch e
    alert ""+e
    false
  
bindEvents = ->
  E = (eid)->document.getElementById eid
  setSpeed = (speed) -> (e) -> stepsPerMs = speed * 1e-3
  E("btn-speed-0").addEventListener "click", setSpeed 0
  E("btn-speed-1").addEventListener "click", setSpeed 10
  E("btn-speed-2").addEventListener "click", setSpeed 30
  E("btn-speed-3").addEventListener "click", setSpeed 100
  E("btn-speed-4").addEventListener "click", setSpeed 300

  E("btn-show-patterns").addEventListener "click", showPatternsWindow

  E("patterns-window").addEventListener "click", (e)->
     if (e.target || e.srcElement).id is "patterns-window"
       hidePatternsWindow()
  E("btn-close-patterns").addEventListener "click", hidePatternsWindow
  E("btn-load-custom").addEventListener "click", (e)->
    if loadCustomPattern() then hidePatternsWindow()
  E("select-pattern").addEventListener "change", (e)->
    if (rle=E("select-pattern").value)
      curves.loadFDL rle
      E("custom-rle").value = rle
      hidePatternsWindow()
  E("btn-make-random").addEventListener "click", (e)->
    loadRandomPattern parseInt(E("random-pattern-size").value, 10)
    hidePatternsWindow()
  
initLibrary = ->
  if window.defaultLibrary?
    select = document.getElementById "select-pattern"
    for fdl in window.defaultLibrary
      parsed = parseFieldDescriptionlLanguage fdl, palette
      select.options[select.options.length] = new Option parsed.name, fdl
  return
  
prevTime = null

animate = ->
  if requestStop
    requestStop = false
    prevTime = null
    return
  requestAnimationFrame animate
  render()
  controls.update()
  stats?.update()

  time = Date.now()
  if prevTime isnt null
    dt = Math.min(time-prevTime, 100) #if FPS falls below 10, slow down simulation instead.
    curves.step stepsPerMs * dt
  prevTime = time
  return
  
render = -> renderer.render scene, camera
  
Detector.addGetWebGLMessage()  unless Detector.webgl

bindEvents()
init()
initLibrary()
animate()
