{Simulator, CircularInterpolatingSimulator} = require "../revca_track"

#calculate vertices of the right n-gon of radius r.
nGonVertices = (n, r) ->
  shape = []
  da = Math.PI*2 / n
  for i in [0 ... n] by 1
    angle = da * i
    shape.push r*Math.cos(angle)
    shape.push r*Math.sin(angle)
  return shape

bottomRight = (pattern)->
  [ Math.max( (xy[0] for xy in pattern) ... ),
    Math.max( (xy[1] for xy in pattern) ... ) ]
###Pure class, without THREE.js code.
#  Creates "blueprints" of the tube geometries
###
exports.Tubing = class Tubing
  constructor: (pattern, options)->
    @size = options.size ? 64

    simulator = new Simulator @size, @size #field size
    [patW, patH] = bottomRight pattern
    #Offset to put pattern to the center
    cx = ((simulator.width - patW)/2) & ~1
    cy = ((simulator.height - patH)/2) & ~1

    simulator.put pattern, cx, cy #pattern roughly at the center
    
    order = options.lanczosOrder ? 3
    interpSteps = options.interpSteps ? 1
    smoothing = options.smoothingPeriod ? 4

    @isim = new CircularInterpolatingSimulator simulator, order, interpSteps, smoothing
    @skipSteps = options.skipSteps ? 1
        
    @chunkSize = options.chunkSize ? 500
    @stepZ = 0.1
    @nCells = pattern.length
    @jumpTreshold = 3

    @prevStates = null #Array of 3 previous states. see explanaiton below, why 3.

    # x, y pairs of the tube cross-section
    @tubeShape = nGonVertices (options.tubeSides ? 3), (options.tubeRadius ? 0.1)

    # Normals from the previous call
    @prevNormals = new Float32Array @nCells*3
    for i in [0...@nCells*3] by 3
      @prevNormals[i] = 1
      @prevNormals[i+1] = 0
      @prevNormals[i+2] = 0
    return
    
  #to make chunk of N segments, we need n+3 states.
  # before-first, first, ... , last, after-last.
  #
  # To make ends of 2 chunks coincide, "first" of one chunk must be the same as "last" of the previous
  #    bf f .... l-1 l al
  #              bf  f f+1
  # thus, 3 states are already calculated, when we are starting new chunk: l-1 (pre-last), l (last), al (after-last)
  makeChunkBlueprint: ->
    unless @prevStates
      @prevStates = ps = []
      for i in [0...3]
        ps.push @isim.getInterpolatedState()
        @isim.nextTime @skipSteps

    #calculate new states.
    states = @prevStates
    for i in [0...@chunkSize] by 1
      states.push @isim.getInterpolatedState()
      @isim.nextTime @skipSteps
    #now we have n+3 states in the array

    #create lines
    tubes = for i in [0...@nCells]
      @makeTubeBlueprint states, i*2

    #store last 3 states for the next frame
    ns = states.length
    @prevStates = [ states[ns-3], states[ns-2], states[ns-1] ]
    return tubes
  chunkLen: -> @chunkSize * @stepZ

  #set of states stores n+3 items, where n is number of pipe parts
  makeTubeBlueprint: (xys, tubeIndex)->
    jumpTreshold = @jumpTreshold
    nJunctions = xys.length - 2
    nPipeParts = xys.length - 3

    tubeEdges = @tubeShape.length / 2 | 0
    
    vs = new Float32Array nJunctions*tubeEdges*3 #x,y,z; for each vertex
    ixs =  new Uint16Array nPipeParts*2*3*tubeEdges #2 triangles for each face
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
      
    shape = @tubeShape
    r = @tubeRadius

    normalsIndex = (tubeIndex/2*3) | 0

    x_pn=@prevNormals[normalsIndex]
    y_pn=@prevNormals[normalsIndex+1]
    z_pn=@prevNormals[normalsIndex+2]

    for iz in [ 1 ... xys.length-1 ]
      xy = xys[iz]
      xyPrev = xys[iz-1]
      xyNext = xys[iz+1]
      
      z = (iz-1)*@stepZ
      x=xy[tubeIndex]
      y=xy[tubeIndex+1]

      #(dx,dy,dz) is an approximate tangent
      dx = xyNext[tubeIndex] - xyPrev[tubeIndex]
      dy = xyNext[tubeIndex+1] - xyPrev[tubeIndex+1] #y-y0
      dz = @stepZ
      
      iqxyz = 1.0 / Math.sqrt( dx*dx+dy*dy+dz*dz ) #normalizing K
      dx *=  iqxyz
      dy *=  iqxyz
      dz *=  iqxyz

      #main normal is calculated by projecting the last normal 
      # pn X tangent:
      tan = x_pn*dx + y_pn*dy + z_pn*dz #tangent component, scaled by iqxyz
      xn1 = x_pn - tan * dx
      yn1 = y_pn - tan * dy
      zn1 = z_pn - tan * dz
      #now normalize it
      inorm1 = 1.0/Math.sqrt(xn1*xn1+yn1*yn1+zn1*zn1)
      if isFinite inorm1
        xn1 *= inorm1
        yn1 *= inorm1
        zn1 *= inorm1
      else
        qxz = 1.0/Math.sqrt( dx*dx+dy*dz)
        xn1= -dz * qxz
        yn1 = 0.0
        zn1 = dx * qxz
      

      #now calculate the third vector, as a X-product of
      # (xn1, yn1, zn1) X (dx, dy, dz)
      xn2 = dy*zn1-dz*yn1
      yn2 = dz*xn1-dx*zn1
      zn2 = dx*yn1-dy*xn1

      vindex = curV / 3 | 0
            
      #and push shape of the tube section    
      for i in [0 ... shape.length] by 2
        vx = shape[i]
        vy = shape[i+1]
        pushXYZ x+xn1*vx+xn2*vy, y+yn1*vx+yn2*vy, z+zn1*vx+zn2*vy

      x_pn = xn1
      y_pn = yn1
      z_pn = zn1
            
      if iz > 1 and (Math.abs(xyPrev[tubeIndex] - x)+Math.abs(xyPrev[tubeIndex+1] - y) < jumpTreshold)
        for j in [0...tubeEdges] by 1
          j1 = (j+1)%tubeEdges
          pushQuad vindex-tubeEdges+j, vindex+j, vindex-tubeEdges+j1, vindex+j1

    @prevNormals[normalsIndex] = x_pn
    @prevNormals[normalsIndex+1] = y_pn
    @prevNormals[normalsIndex+2] = z_pn
    if curV isnt vs.length then throw new Error "Not all vertices filled"

    if curIx isnt ixs.length
      ixs = ixs.subarray 0, curIx

    #Blueprint: vertices and indices
    return{
      v: vs
      idx: ixs
    }
    
