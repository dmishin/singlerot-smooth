{InterpolatingSimulator, Simulator, CircularInterpolatingSimulator} = require "./flight"

main = ->
  {Cells} = require "/home/dim/Prog/js-revca/scripts-src/cells"

  console.log JSON.stringify lanczosKernel 2, 4
  
  s = new Simulator 10, 10
  s.put Cells.from_rle "$2o2$2o"

  for i in [0..12] by 1
    s.step()
    s.step()
    c1 = s.getCells()
    Cells.normalize c1
    console.log Cells.to_rle c1
  return

                
mainSim = ->
  s = new Simulator 10, 10
  s.put [[1,1]]
  isim = new InterpolatingSimulator s, 3, 6
  xx = []
  yy = []
  for t in [0..100]
    state = isim.getInterpolatedState()
    xx.push state[0]
    yy.push state[1]
    console.log "#### Simulator returned state: #{JSON.stringify state}"
    isim.nextTime 1
  console.log "import numpy as np"
  console.log "import matplotlib.pyplot as pp"
  console.log "x=np.array(#{JSON.stringify xx})"
  console.log "y=np.array(#{JSON.stringify yy})"
  console.log "pp.plot(x,y)"
  console.log "pp.show()"
  return
  
