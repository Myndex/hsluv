# https://gist.github.com/3716319
hslToRgb = (h, s, l) ->
  h /= 360
  if s == 0
    r = g = b = l # achromatic
  else
    hue2rgb = (p, q, t) ->
      if t < 0 then t += 1
      if t > 1 then t -= 1
      if t < 1/6 then return p + (q - p) * 6 * t
      if t < 1/2 then return q
      if t < 2/3 then return p + (q - p) * (2/3 - t) * 6
      return p

    q = if l < 0.5 then l * (1 + s) else l + s - l * s
    p = 2 * l - q
    r = hue2rgb(p, q, h + 1/3)
    g = hue2rgb(p, q, h)
    b = hue2rgb(p, q, h - 1/3)
  [r, g, b]

hslToHex = (h, s, l) ->
  rgb = hslToRgb h, s / 100, l / 100
  return $.husl._conv.rgb.hex rgb

randomHue = ->
  Math.floor Math.random() * 360

$('#demo1').click ->
  $(this).closest('div').find('.demo').each ->
    $(this).css 'background-color', $.husl.toHex randomHue(), 90, 60

$('#demo2').click ->
  $(this).closest('div').find('.demo').each ->
    $(this).css 'background-color', hslToHex randomHue(), 90, 60

$('#demo1').click()
$('#demo2').click()

$('#rainbow-husl div').each (index) ->
  $(this).css 'background-color', $.husl.toHex index * 36, 90, 60
$('#rainbow-hsl div').each (index) ->
  $(this).css 'background-color', hslToHex index * 36, 90, 60





kappa = 24389 / 27
epsilon = 216 / 24389
m =
  R: [ 3.240454162114103, -1.537138512797715, -0.49853140955601 ]
  G: [ -0.96926603050518, 1.876010845446694,  0.041556017530349 ]
  B: [ 0.055643430959114, -0.20402591351675,  1.057225188223179 ]

getBounds = (L) ->
  sub1 = Math.pow(L + 16, 3) / 1560896
  sub2 = if (sub1 > epsilon) then sub1 else (L / kappa)
  ret = {}
  for channel in ['R', 'G', 'B']
    [m1, m2, m3] = m[channel]
    for t in [0, 1]

      top1 = (1441272 * m3 - 4323816 * m1) * sub2
      top2 = (-12739311 * m3 - 11700000 * m2 - 11120499 * m1) * L * sub2 + 11700000 * t * L
      bottom = -((9608480 * m3 - 1921696 * m2) * sub2 + 1921696 * t)

      V = (top1 + top2) / bottom

      s = top1 / bottom
      c = top2 / bottom

      ret[channel + t] = [c, s]
  return ret






size = 400

height = size
width = size
maxRadius = size / 2



toCart = (angle, radius) ->
  return {
    x: (height / 2) + radius * Math.cos(angle)
    y: (width / 2) + radius * Math.sin(angle)
  }

normalizeRad = (hrad) ->
  return (hrad + 2 * Math.PI) % (2 * Math.PI)

intersection = (c1, s1, c2, s2) ->
  x = (c1 - c2) / (s2 - s1)
  y = c1 + x * s1
  return [x, y]

intersection3 = (line1, line2) ->
  return intersection line1[0], line1[1], line2[0], line2[1]

intersection2 = (line1, point) ->
  line2 = [0, point[1] / point[0]]
  int = intersection3 line1, line2
  if int[0] > 0 and int[0] < point[0]
    return int
  if int[0] < 0 and int[0] > point[0]
    return int
  return null

distanceFromPole = (point) ->
  Math.sqrt(Math.pow(point[0], 2) + Math.pow(point[1], 2))

getIntersections = (lines) ->
  [fname, f] = _.first lines
  rest = _.rest lines
  if rest.length == 0
    return []
  intersections = _.map rest, (r) ->
    [rname, r] = r
    {
      point: intersection3 f, r
      names: [fname, rname]
    }
    
  return intersections.concat getIntersections rest

dominoSortMatch = (dominos, match) ->
  if dominos.length == 1
    return dominos

  {_first, rest} = _.groupBy dominos, (domino) ->
    if match in domino then '_first' else 'rest'

  first = _first[0]

  next = if first[0] != match then first[0] else first[1]
  return [first].concat dominoSortMatch rest, next

dominoSort = (dominos) ->
  first = _.first dominos
  rest = _.rest dominos
  [first].concat dominoSortMatch rest, first[1]

sortIntersections = (intersections) ->
  dominos = dominoSort _.pluck intersections, 'names'
  _.map dominos, (domino) ->
    _.find intersections, (i) ->
      i.names[0] == domino[0] and i.names[1] == domino[1]

hs = (L) ->
  ret = []
  he1 = $.husl._hradExtremum L
  for channel in ['R', 'G', 'B']
    for limit in [0, 1]
      ret.push normalizeRad(he1(channel, limit))
  ret.sort()
  return ret

$canvas     = $ '#picker canvas'
$svg        = $ '#picker svg'
$background = $ "#picker svg g.background"
$foreground = $ "#picker svg g.foreground"

$controlHue        = $ "#picker .control-hue"
$controlSaturation = $ "#picker .control-saturation"
$controlLightness  = $ "#picker .control-lightness"

ctx = $canvas[0].getContext '2d'
contrasting = null

background = d3.select("#picker svg g.background")
foreground = d3.select("#picker svg g.foreground")


redrawSquare = (x, y, dim) ->
  vx = (x - 200) / scale
  vy = (y - 200) / scale
  polygon = d3.geom.polygon [
    [vx, vy], [vx, vy + dim], [vx + dim, vy + dim], [vx + dim, vy]
  ]
  shape.clip(polygon)
  if polygon.length > 0
    [vx, vy] = polygon.centroid()
    hex = $.husl._conv.rgb.hex $.husl._conv.xyz.rgb $.husl._conv.luv.xyz [L, vx, vy]
    ctx.fillStyle = hex
    ctx.fillRect x, y, dim, dim

redrawCanvas = (dim) ->
  ctx.clearRect 0, 0, width, height
  ctx.save()

  first = _.first sortedIntersections
  rest = _.rest sortedIntersections

  ctx.beginPath()
  ctx.moveTo(200 + first[0] * scale, 200 + first[1] * scale)
  for r in rest
    ctx.lineTo(200 + r[0] * scale, 200 + r[1] * scale)
  ctx.closePath()
  ctx.clip()

  xn = width / dim / 2
  yn = height / dim / 2

  for x in [0..xn * 2]
    for y in [0..yn * 2]
      vx = x * dim
      vy = y * dim
      redrawSquare vx, vy, dim

  ctx.restore()

H = 0
S = 100
L = 50
scale = null
sortedIntersections = []
bounds = []
shape = null
pointer = null

redrawBackground = ->
  background[0][0].innerHTML = ''

  pairs = _.map hs(L), (hrad) ->
    C = $.husl._maxChroma L, hrad * 180 / Math.PI
    return [hrad, C]

  Cs = _.map pairs, (pair) -> pair[1]

  maxC = Math.max Cs...
  minC = Math.min Cs...

  bounds = getBounds L

  intersections = []
  for i in getIntersections _.pairs bounds
    good = true
    for [name, bound] in _.pairs bounds
      if name in i.names
        continue
      int = intersection2 bound, i.point
      if int != null
        good = false
    if good
      intersections.push(i)

  cleanBounds = []
  for {point, names} in intersections
    cleanBounds = _.union cleanBounds, names

  longest = 0
  for {point} in intersections
    length = distanceFromPole point
    if length > longest
      longest = length

  scale = 190 / longest

  sortedIntersections = _.pluck sortIntersections(intersections), 'point'

  shape = d3.geom.polygon sortedIntersections
  if shape.area() < 0
    sortedIntersections.reverse()
    shape = d3.geom.polygon sortedIntersections

  contrasting = if L > 50 then '#1b1b1b' else '#ffffff'

  background.append("circle")
    .attr("cx", 0)
    .attr("cy", 0)
    .attr("r", scale * minC)
    .attr("transform", "translate(200, 200)")
    .attr("stroke", contrasting)
    .attr("stroke-width", 2)
    .attr("fill", "none")

  background.append("circle")
    .attr("cx", 0)
    .attr("cy", 0)
    .attr("r", 2)
    .attr("transform", "translate(200, 200)")
    .attr("fill", contrasting)

redrawForeground = ->
  foreground[0][0].innerHTML = ''

  maxChroma = $.husl._maxChroma L, H
  chroma = maxChroma * S / 100
  hrad = H / 360 * 2 * Math.PI

  foreground.append("circle")
    .attr("cx", 0)
    .attr("cy", 0)
    .attr("r", 190)
    .attr("transform", "translate(200, 200)")
    .attr("fill", "#ffffff")
    .attr("fill-opacity", "0.0")
    .attr("stroke", "#ffffff")
    .attr("stroke-width", 2)

  foreground.append("circle")
    .attr("cx", chroma * Math.cos(hrad) * scale)
    .attr("cy", chroma * Math.sin(hrad) * scale)
    .attr("r", 4)
    .attr("transform", "translate(200, 200)")
    .attr("fill", "none")
    .attr("stroke", contrasting)
    .attr("stroke-width", 2)

  colors = d3.range(0, 360, 10).map (_) -> $.husl.toHex _, S, L
  d3.select("#picker div.control-hue").style {
    'background': 'linear-gradient(to right,' + colors.join(',') + ')'
  }

  colors = d3.range(0, 100, 10).map (_) -> $.husl.toHex H, _, L
  d3.select("#picker div.control-saturation").style {
    'background': 'linear-gradient(to right,' + colors.join(',') + ')'
  }

  colors = d3.range(0, 100, 10).map (_) -> $.husl.toHex H, S, _
  d3.select("#picker div.control-lightness").style {
    'background': 'linear-gradient(to right,' + colors.join(',') + ')'
  }

redrawSliderPositions = ->

  sliderHue.value        H
  sliderSaturation.value S
  sliderLightness.value  L

  console.log 'redddd'
  sliderHue.redraw()
  sliderSaturation.redraw()
  sliderLightness.redraw()


adjustPosition = (x, y) ->
  pointer = [x / scale, y / scale]

  hrad = normalizeRad Math.atan2 pointer[1], pointer[0]

  H = hrad / 2 / Math.PI * 360

  maxChroma = $.husl._maxChroma L, H
  pointerDistance = distanceFromPole(pointer)

  S = Math.min(pointerDistance / maxChroma * 100, 100)

  redrawForeground()
  redrawSliderPositions()

$foreground.mousedown (e) ->
  e.preventDefault()
  offset = $canvas.offset()
  x = e.pageX - offset.left - 200
  y = e.pageY - offset.top - 200
  
  adjustPosition x, y

dragmove = ->
  x = d3.event.x - 200
  y = d3.event.y - 200

  adjustPosition x, y

drag = d3.behavior.drag()
  .on("drag", dragmove)

foreground.call(drag)

sliderHue = d3.slider()
  .min(0)
  .max(360)
  .on 'slide', (e, value) ->
    H = value
    redrawForeground()

sliderSaturation = d3.slider()
  .min(0)
  .max(100)
  .on 'slide', (e, value) ->
    S = value
    redrawForeground()

sliderLightness = d3.slider()
  .min(1)
  .max(99)
  .on 'slide', (e, value) ->
    L = value
    redrawBackground()
    redrawCanvas(10)
    redrawForeground()

d3.select("#picker div.control-hue").call(sliderHue)
d3.select("#picker div.control-saturation").call(sliderSaturation)
d3.select("#picker div.control-lightness").call(sliderLightness)

redrawBackground()
redrawCanvas(10)
redrawForeground()
redrawSliderPositions()
