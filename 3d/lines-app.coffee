{Simulator, CircularInterpolatingSimulator} = require "../revca_track"

container = undefined
stats = undefined
camera = undefined
scene = undefined
renderer = undefined
mesh = undefined

init = ->
  container = document.getElementById("container")
  
  #
  camera = new THREE.PerspectiveCamera(27, window.innerWidth / window.innerHeight, 1, 4000)
  camera.position.z = 2750
  scene = new THREE.Scene()
  segments = 10000
  geometry = new THREE.BufferGeometry()
  material = new THREE.LineBasicMaterial(vertexColors: THREE.VertexColors)
  positions = new Float32Array(segments * 3)
  colors = new Float32Array(segments * 3)
  r = 800
  for i in [0...segments] by 1
    x = Math.random() * r - r / 2
    y = Math.random() * r - r / 2
    z = Math.random() * r - r / 2
    
    # positions
    positions[i * 3] = x
    positions[i * 3 + 1] = y
    positions[i * 3 + 2] = z
    
    # colors
    colors[i * 3] = (x / r) + 0.5
    colors[i * 3 + 1] = (y / r) + 0.5
    colors[i * 3 + 2] = (z / r) + 0.5
  geometry.addAttribute "position", new THREE.BufferAttribute(positions, 3)
  geometry.addAttribute "color", new THREE.BufferAttribute(colors, 3)
  geometry.computeBoundingSphere()
  mesh = new THREE.Line(geometry, material)
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

#
animate = ->
  requestAnimationFrame animate
  render()
  stats.update()
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