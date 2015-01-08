{Simulator, CircularInterpolatingSimulator} = require "../revca_track"
{parseRle} = require "../rle"
###Pure class, without THREE.js code.
#  Creates "blueprints" of the tube geometries
###
exports.Tubing = class Tubing
  constructor: ->
    pattern = parseRle "$3b2o$2bobob2o$2bo5bo$7b2o$b2o$bo5bo$2b2obobo$5b2oo"
    simulator = new Simulator 64, 64 #field size
    patW = Math.max( (xy[0] for xy in pattern) ... )
    patH = Math.max( (xy[1] for xy in pattern) ... )
    #Offset to put pattern to the center
    cx = ((simulator.width - patW)/2) & ~1
    cy = ((simulator.height - patH)/2) & ~1

    simulator.put pattern, cx, cy #pattern roughly at the center
    
    order = 3
    interpSteps = 1
    smoothing = 4
    @tubeRadius = 0.1
    @isim = new CircularInterpolatingSimulator simulator, order, interpSteps, smoothing

    @chunkSize = 1000
    @stepZ = 0.1
    @nCells = pattern.length
    @jumpTreshold = 3
    @lastState = null

  makeChunkBlueprint: ->
    unless @lastState
      @lastState = @isim.getInterpolatedState()
    states = for i in [0...@chunkSize] by 1
      @isim.nextTime 1
      @isim.getInterpolatedState()
    #create lines
    tubes = for i in [0...@nCells]
      @makeTubeBlueprint states, i*2, @lastState
    @lastState = states[states.length-1]
    return tubes
  chunkLen: -> @chunkSize * @stepZ
  makeTubeBlueprint: (xys, i, xy0)->
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

    if curV isnt vs.length then throw new Error "Not all vertices filled"

    blueprint =
      v: vs
      v_used: curV
      idx: ixs
      idx_used: curIx
    return blueprint
    
