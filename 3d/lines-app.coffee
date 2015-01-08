{Simulator, CircularInterpolatingSimulator} = require "../revca_track"
{parseRle} = require "../rle"

container = undefined
stats = undefined
camera = undefined
scene = undefined
renderer = undefined
controls = undefined

palette = [0xfe8f0f, 0xf7325e, 0x7dc410, 0xfef8cf, 0x0264ed]


class ChunkedFlyingCurves
  constructor: ->
    pattern = parseRle "$3b2o$2bobob2o$2bo5bo$7b2o$b2o$bo5bo$2b2obobo$5b2oo"
    simulator = new Simulator 64, 64 #field size
    patW = Math.max( (xy[0] for xy in pattern) ... )
    patH = Math.max( (xy[1] for xy in pattern) ... )
    #Offset to put pattern to the center
    cx = ((simulator.width - patW)/2) & ~1
    cy = ((simulator.height - patH)/2) & ~1
    console.log "Putting pattern at #{cx}, #{cy}"
    simulator.put pattern, cx, cy #pattern roughly at the center
    
    order = 3
    interpSteps = 1
    smoothing = 4
    @tubeRadius = 0.1
    @isim = new CircularInterpolatingSimulator simulator, order, interpSteps, smoothing

    @stepZ = 1 / interpSteps

    @chunkSize = 200
    @stepZ = 0.1
    @scale = scale = 30
    @nCells = pattern.length
    @colors = (palette[i%palette.length] for i in [0...@nCells] by 1)
    @group = new THREE.Object3D
    @chunks = []
    @materials = for color in @colors
      new THREE.MeshBasicMaterial color: color

    @zMin = -100
    @lastChunkZ = 0
    @jumpTreshold = 3

    @group.scale.set scale, scale, scale
    @group.position.set -0.5*simulator.width*scale, -0.5*simulator.height*scale, 0
    @group.updateMatrix()
    
        
  makeChunk: ->
    unless @lastState
      @lastState = @isim.getInterpolatedState()
    states = for i in [0...@chunkSize] by 1
      @isim.nextTime 1
      @isim.getInterpolatedState()
    #create lines
    chunk = new THREE.Object3D
    for i in [0...@nCells]
      tubeGeom = @createTube states, i*2, @lastState
      tube = new THREE.Mesh tubeGeom, @materials[i]
      chunk.add tube
    @lastState = states[states.length-1]
    return chunk


  createTube: (xys, i, xy0)->
    jumpTreshold = @jumpTreshold
    vs = new Float32Array xys.length*4*3 #x,y,z; 4 vertices
    ixs =  new Uint16Array (xys.length-1)*2*3*4 #2 triangles
    curIx = 0
    curV = 0
    pushXYZ = (x,y,z)->
      vs[curV] = x
      vs[curV+1] = y
      vs[curV+2] = z      
      curV += 3
      return
      
    pushQuad = (i1,i2, i3, i4) ->
      ixs[curIx  ] = i1
      ixs[curIx+1] = i2
      ixs[curIx+2] = i3
      ixs[curIx+3] = i2
      ixs[curIx+4] = i4
      ixs[curIx+5] = i3
      curIx += 6
      return
      
    r = @tubeRadius

    x0 = xy0[i]
    y0 = xy0[i]
    for xy, iz in xys
      z = iz*@stepZ
      x=xy[i]
      y=xy[i+1]

      #vectr from the previous point to this
      dx = x-x0
      dy = y-y0
      dz = @stepZ
      x0 = x
      y0 = y

      #compute normals
      # noraml of form
      # xn1, 0, zn1
      # xn1 dx + zn1 dz = 0
      # xn1 dx = - zn1 dz
      # zn1 = - (dx/dz) xn1
      # #
      # xn1^2 ( 1 + (dx/dz)^2 ) = 1
      # xn1^2 = 1/( 1 + (dx/dz)^2 )
      # xn1^2 = dz^2 / (dx^2+dz^2)
      # 
      # xn1 =   dz / sqrt(dx^2+dz^2)
      # zn1 = - dx / sqrt(dx^2+dz^2)

      qdxdz = r / Math.sqrt( dx*dx+dz*dz)
      xn1 = dz * qdxdz
      zn1 = -dx * qdxdz
      
      qdydz = r / Math.sqrt( dy*dy+dz*dz)
      yn2 = dz * qdydz
      zn2 = -dy * qdydz
      
            
      vindex = curV / 3 | 0

      pushXYZ x-xn1,y,z-zn1
      pushXYZ x,y+yn2,z+zn2
      pushXYZ x+xn1,y,z+zn1
      pushXYZ x,y-yn2,z-zn2
      if iz >0 and Math.abs(dx)+Math.abs(dy) < jumpTreshold
        for j in [0...4]
          j1 = (j+1)%4
          pushQuad vindex-4+j, vindex+j, vindex-4+j1, vindex+j1

    if curIx isnt ixs.length
      #then throw new Error "Not all indices filled"
      console.log "Indices skip: #{ixs.length - curIx}"
      ixs = ixs.subarray 0, curIx
    if curV isnt vs.length then throw new Error "Not all vertices filled"

    tube = new THREE.BufferGeometry()
    
    tube.addAttribute 'position', new THREE.BufferAttribute(vs, 3)
    tube.addAttribute 'index', new THREE.BufferAttribute(ixs, 1)

    #tube.offsets.push {start: 0;index: 0; count: vs.length}

    tube.computeBoundingSphere()
    return  tube
    
  step: (dz) ->
    i = 0
    while i < @chunks.length
      chunk = @chunks[i]
      chunk.position.setZ chunk.position.z-dz
      if chunk.position.z < @zMin
        console.log "Discarding chunk #{i}"
        @chunks.splice i, 1
        @group.remove chunk
      else
        i += 1
    @lastChunkZ -= dz
    if @lastChunkZ < 0
      console.log "last chunk is at #{@lastChunkZ}, Cerating new chunk..."
      chunk = @makeChunk()
      chunkLen = @chunkSize * @stepZ
      @lastChunkZ += chunkLen
      chunk.position.setZ @lastChunkZ
      @chunks.push chunk
      @group.add chunk
      console.log "Created, addded at #{@lastChunkZ} chunk of len #{chunkLen}"
    return
      
      

curves = undefined    
          
init = ->
  container = document.getElementById("container")
  
  #
  camera = new THREE.PerspectiveCamera(27, window.innerWidth / window.innerHeight, 1, 10500)
  camera.position.z = 2750
  scene = new THREE.Scene()
  scene.fog = new THREE.Fog 0x050505, 2000, 10500
  #scene.add new THREE.AmbientLight 0x444444 

  controls = new THREE.TrackballControls  camera

  controls.rotateSpeed = 1.0
  controls.zoomSpeed = 1.2
  controls.panSpeed = 0.8

  controls.noZoom = false
  controls.noPan = false

  controls.staticMoving = true
  controls.dynamicDampingFactor = 0.3

  controls.keys = [ 65, 83, 68 ]

  #controls.addEventListener 'change', render

  curves = new ChunkedFlyingCurves

  lines = new THREE.Object3D
  lines.add curves.group
  scene.add lines
  
  #
  renderer = new THREE.WebGLRenderer(antialias: false)
  renderer.setSize window.innerWidth, window.innerHeight
  renderer.gammaInput = true
  renderer.gammaOutput = true
  container.appendChild renderer.domElement
  
  #
  stats = new Stats()
  stats.domElement.style.position = "absolute"
  stats.domElement.style.top = "0px"
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


prevTime = null
stepsLeft = 0
stepsPerMs = 15 / 1000

animate = ->
  requestAnimationFrame animate
  render()
  controls.update()
  stats.update()

  time = Date.now()
  if prevTime isnt null
    dt = time-prevTime
    #steps = stepsLeft + stepsPerMs * dt
    #iSteps = Math.round steps
    #stepsLeft = steps - iSteps
    #curves.step Math.min 100, iSteps #for old line-based code
    curves.step stepsPerMs * dt
    
    #to make movement smoother, shift lines by the remaining noninteger fraction.
    #curves.offsetZ stepsLeft
  prevTime = time
  return
  
render = ->
  #time = Date.now() * 0.0001
  #mesh.rotation.x = time * 0.25
  #mesh.rotation.y = time * 0.5
  renderer.render scene, camera
  return
  
Detector.addGetWebGLMessage()  unless Detector.webgl
init()
animate()