{Simulator, CircularInterpolatingSimulator} = require "../revca_track"
{parseRle} = require "../rle"
{Tubing} = require "./tubing"

container = undefined
stats = undefined
camera = undefined
scene = undefined
renderer = undefined
controls = undefined

palette = [0xfe8f0f, 0xf7325e, 0x7dc410, 0xfef8cf, 0x0264ed]

  

class ChunkedFlyingCurves
  constructor: ->
    @tubing = tubing = new Tubing
    
    @scale = scale = 30

    @colors = (palette[i%palette.length] for i in [0...tubing.nCells] by 1)
    @group = new THREE.Object3D
    @chunks = []
    @materials = for color in @colors
      new THREE.MeshBasicMaterial color: color

    @zMin = -100
    @lastChunkZ = 0

    @group.scale.set scale, scale, scale
    simulator = @tubing.isim.simulator
    @group.position.set -0.5*simulator.width*scale, -0.5*simulator.height*scale, 0
    @group.updateMatrix()
    
        
  makeChunk: ->
    blueprint = @tubing.makeChunkBlueprint()

    #create lines
    chunk = new THREE.Object3D
    for tubeBp, i in blueprint
      tubeGeom = @createTube tubeBp
      tube = new THREE.Mesh tubeGeom, @materials[i]
      chunk.add tube
    return chunk


  createTube: (blueprint)->
    tube = new THREE.BufferGeometry()

    vs = blueprint.v.subarray 0, blueprint.v_used
    ixs = blueprint.idx.subarray 0, blueprint.idx_used
    
    tube.addAttribute 'position', new THREE.BufferAttribute(vs, 3)
    tube.addAttribute 'index', new THREE.BufferAttribute(ixs, 1)
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
      chunkLen = @tubing.chunkLen()
      @lastChunkZ += chunkLen
      chunk.position.setZ @lastChunkZ
      @chunks.push chunk
      @group.add chunk
      console.log "Created, added at #{@lastChunkZ} chunk of len #{chunkLen}"
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