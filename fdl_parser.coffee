{parseRle} = require "./rle"
#Parses text in FDL (Field Description Language), executes is and creates pattern
# Language description:
#   program ::= "" | instruction ; program
#   instruciton ::= "rle" <rle text> 
#                 | "at" <x :: integer> <y::integer> 
#                 | "colors" colors_list
#                 | "--" <comment text>
#
#  colors_list ::= color | color , colors_list
#
#  color ::= <any CSS color description, with space replaced by "_"
exports.parseFieldDescriptionlLanguage = (fdlText, defaultPalette) ->
  FLD =
    rle: /^\s*([bo0-9\$]+)\s*$/
    at:  /^\s*at\s+(-?\d+)\s+(-?\d+)\s*$/
    colors: /^\s*colors\s+(.+)$/
    comment: /^\s*--\s*(.*)$/
    empty: /^\s*$/
    size: /^\s*size\s+(\d+)\s+(\d+)\s*$/
    rule: /^\s*rule\s+(.+)\s*$/

  pos = [0,0]
  pattern = []
  colors = []
  defaultPalette = defaultPalette ? ["#FF0000", "#FFFF00", "#00FF00", "#00FFFF", "#0000FF", "#FF00FF"]
  curColors = defaultPalette
  size = null
  descriptions = []
  rule = null
  for line in fdlText.split "\n"
   for instruction in line.split ";"
    instruction = instruction.trim()
    if m = instruction.match FLD.rle
      for [x,y],i in parseRle m[1]
        pattern.push [x+pos[0], y+pos[1]]
        colors.push curColors[colors.length % curColors.length]
    else if m = instruction.match FLD.at
      pos = [parseInt(m[1], 10), parseInt(m[2],10)]
    else if m = instruction.match FLD.size
      size = [parseInt(m[1], 10), parseInt(m[2],10)]
    else if m = instruction.match FLD.colors
      colorsText = m[1].trim()
      curColors = if colorsText is "default"
        defaultPalette
      else
        (c.trim() for c in colorsText.split ":")
    else if instruction.match(FLD.empty)
      null
    else if m = instruction.match(FLD.comment)
      descriptions.push m[1]
    else if m = instruction.match(FLD.rule)
      rule = makeRule m[1].split('|').join(';')
    else
      throw new Error "Unexpected instruction: #{instruction}"
  return {
    pattern: pattern
    colors: colors
    size: size
    name: descriptions.join("\n")
    rule: rule
  }

