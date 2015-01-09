{Tubing} = require "./tubing"

tubing = undefined


initialize = (options)->
  unless options.pattern?
    throw new Error "Pattern not specified!"
  tubing = new Tubing options.pattern, options
  self.postMessage
    cmd: "init"
    nCells: tubing.nCells
    fldWidth: tubing.isim.simulator.width
    fldHeight: tubing.isim.simulator.height
    chunkLen: tubing.chunkLen()

generateChunk = (taskId)->
  bp = tubing.makeChunkBlueprint()
  transferables=[]
  for tubeBp in bp
    transferables.push tubeBp.v.buffer
    transferables.push tubeBp.idx.buffer
    
  self.postMessage {
    cmd: "chunk"
    taskId: taskId
    blueprint: bp
    }, transferables
  
#worker message handler
self.addEventListener "message", (e)->
  cmd = e.data.cmd
  unless cmd?
    throw new Error "Unknown message received! #{JSON.stringify e.data}"

  switch cmd
    when "init"
      initialize e.data
    when "chunk"
      generateChunk e.data.taskId
    else
      throw new Error "Unknown command received by worker: #{cmd}"