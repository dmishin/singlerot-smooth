{Simulator, CircularInterpolatingSimulator} = require "../revca_track"

container = undefined
stats = undefined
camera = undefined
scene = undefined
renderer = undefined
mesh = undefined
lines = []

class FlowingLine
  constructor: (@segments) ->
    @geometry = new THREE.BufferGeometry()
    @geometry.dynamic = true
    @material = new THREE.LineBasicMaterial({vertexColors: THREE.VertexColors, linewidth:3})
    @positions = new Float32Array(segments * 3)
    @colors = new Float32Array(segments * 3)
    
    @geometry.addAttribute "position", new THREE.BufferAttribute(@positions, 3)
    @geometry.addAttribute "color", new THREE.BufferAttribute(@colors, 3)
    #@geometry.computeBoundingSphere()
    @mesh = new THREE.Line(@geometry, @material)
    
  setDirty: ->
    @geometry.attributes[ "position" ].needsUpdate = true
    @geometry.attributes[ "color" ].needsUpdate = true
    @geometry.needsUpdate = true
    
  initial: (x, y, z0, z1) ->
    ps = @positions
    cs = @colors
    for i in [0...@segments] by 1
      i3=i*3
      z = z0 + ((z1-z0)/(@segments-1))*i
      ps[i3] = x
      ps[i3+1] = y
      ps[i3+2] = z
      console.log "Add line point #{x} #{y} #{z}"
      cs[i3]=1
      cs[i3+1]=1
      cs[i3+2]=1
    @setDirty()
      
  flow: (x, y) ->
    ps = @positions
    for i in [0...(@segments-1)] by 1
      i3=i*3
      ps[i3] = ps[i3+3]
      ps[i3+1] = ps[i3+4]
    i3 = (@segments-1)*3
    ps[i3]   =x
    ps[i3+1] =y
    @setDirty()
    
init = ->
  container = document.getElementById("container")
  
  #
  camera = new THREE.PerspectiveCamera(27, window.innerWidth / window.innerHeight, 1, 4000)
  camera.position.z = 2750
  scene = new THREE.Scene()

  
  line = new FlowingLine 100 #segments
  line.initial 0, 0, -200, 200

  lines.push line

  mesh = new THREE.Object3D
  mesh.add line.mesh

  scene.add mesh
  
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
  return

geometryTime = 0

animate = ->
  requestAnimationFrame animate
  render()
  stats.update()
  for line in lines
    #updateGeometry line, geometryTime, true
    line.flow Math.random()*200+100, Math.random()*200+100
  geometryTime += 0.001
  return
  
render = ->
  time = Date.now() * 0.001
  mesh.rotation.x = time * 0.25
  mesh.rotation.y = time * 0.5
  renderer.render scene, camera
  return
  
Detector.addGetWebGLMessage()  unless Detector.webgl
init()
animate()