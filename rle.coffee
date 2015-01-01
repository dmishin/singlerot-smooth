exports.parseRle = parseRle = (rle) ->
  x = 0
  y = 0
  curCount = 0
  pattern=[]
  for i in [0 ... rle.length]
    c = rle.charAt i
    if "0" <= c <= "9"
      curCount = curCount * 10 + parseInt(c,10)
    else if c in [" ", "\n", "\r", "\t"]
      continue
    else if c is "!"
      return
    else
      count = Math.max(curCount, 1)
      curCount = 0
      switch c
        when "b"
          x += count
        when "$"
          y += count
          x = 0
        when "o"
          for j in [0...count] by 1
            pattern.push [x, y]
            x+=1
        else
          throw new Error "Unexpected character '#{c}' at position #{i}"
  return pattern