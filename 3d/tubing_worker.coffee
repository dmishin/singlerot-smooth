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

setOptions= (options)->
  throw new Error "Not initialized" unless tubing?
  for [name, value] in options
    tubing[name] = value
  return
  
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
    when "set"
      setOptions e.data.options
    else
      throw new Error "Unknown command received by worker: #{cmd}"