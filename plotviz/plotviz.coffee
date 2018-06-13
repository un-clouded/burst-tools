

p= ->
  console.log.apply  this, arguments



# Constructs a new DOM element, optionally using a function to construct and
# attach child elements.
#
#   elm 'p', {}, 'text'
#   elm 'tr', () ->
#     elm 'td', class: row, () ->
#       'content'
#
elm = (tag, attributes, builder= undefined) ->
  #p "elm #{tag}, #{attributes}, #{builder}"
  # If no attributes were given then the builder is in the "attributes"
  # parameter.  "builder" could either be: 1) a string, 2) a DOM element, or 3)
  # a function that when invoked returns either an element, a string or a list
  # where each item is either an element or a string
  #if builder is null and (typeof attributes in (typeof e for e in [Function,""]) or attributes.nodeType? or $.isArray attributes)
  #  builder = attributes
  #  attributes = {}
  # If there are only two parameters then `attributes` might either be
  # attributes or the builder (or content)
  if arguments.length < 3  and  not $.isPlainObject attributes
    builder = attributes
    attributes = {}
  #p attributes:attributes, builder:builder
  # Construct the element
  xmlns = attributes.xmlns
  el =
    if xmlns?
      document.createElementNS  xmlns, tag
    else
      document.createElement  tag
  # Add any attributes
  for name, value of attributes
    el.setAttribute  name, value
  # Helper:
  add = (el, child) ->
    #p add:child
    child = document.createTextNode  child if typeof child is typeof ''
    el.appendChild  child
  # Construct and attach any children
  if builder?
    children = if typeof builder is typeof Function then builder() else builder
    if $.isArray  children
      for child in children
        add  el, child
    else
      add  el, children
  el



class Bucket

  constructor: (@first_nonce)->
    @next_nonce = @first_nonce.plus  NONCES_PER_BUCKET  # first nonce *after* the given range
    @reset()

  reset: ->
    @nonces = Big 0

  consider: (first_nonce, nonce_count)->
    next_nonce = first_nonce.plus  nonce_count
    # Like clipping one range to the "window" of another
    first_nonce = @first_nonce if first_nonce.lt  @first_nonce
    next_nonce = @next_nonce if @next_nonce.lt  next_nonce
    length = next_nonce.minus  first_nonce
    # if `length` is negative then the range lies completely outside the window
    @nonces = @nonces.plus  length  unless length.lt  0

  toString: ->
    first_nonce: @first_nonce.toString()
    nonces: @nonces.toString()



ArcChart: class ArcChart

  constructor: (@canvas_element)->
    #

  show: (values, styler)->
    ct = @canvas_element.getContext '2d'
    radius = @canvas_element.height / 2 - 16
    center_x = @canvas_element.width / 2
    center_y = @canvas_element.height / 2
    inner_radius = radius / 2
    # work out the angle movement from East to North, clockwise is positive
    # so this is negative
    to_north = 2*Math.PI * -1/4
    full_sweep = 2 * Math.PI
    for value, i in values
      scale = values.length
      # angle 0 (radians) is from +x, measured clockwise
      from_angle = full_sweep * i / scale
      # full scale is 90 degrees (PI / 2)
      sweep = full_sweep / scale
      to_angle = from_angle + sweep
      ct.fillStyle = styler  value, i
      ct.beginPath()
      ct.arc  center_x, center_y, radius, to_north+from_angle, to_north+to_angle
      x = center_x + Math.sin(to_angle) * inner_radius
      y = center_y - Math.cos(to_angle) * inner_radius
      ct.lineTo  x, y
      ct.arc  center_x, center_y, inner_radius, to_north+to_angle, to_north+from_angle, true
      ct.fill()



BUCKET_COUNT = 128
# JavaScript can't accurately represent integers with more than 53 bits of
# precision (32 if using bitwise operators), hence `Big`:
TOTAL_NONCE_COUNT = Big "18446744073709551616"
NONCES_PER_BUCKET = TOTAL_NONCE_COUNT.div BUCKET_COUNT

BUCKETS = [0 .. BUCKET_COUNT-1].map (i)->
  new Bucket NONCES_PER_BUCKET.times i



# Provides a list of buckets spanning the range of possible values for 64-bit
# integers.  Each bucket contains the number of plot files that fall in to this
# bucket.  Should the range of nonces in a plot file span multiple buckets, the
# "count" which is really a weight is apportioned between buckets.
#
parse = (data) ->
  bucket.reset() for bucket in BUCKETS
  lines = data.trim().split "\n"
  for line in lines
    # Anything prior to the last path separator should be ignored
    groups = line.match /[^\\/]+$/
    file_name = groups[0]
    if groups = file_name.match /^\d+_(\d+)_(\d+)_\d+$/
      [first_nonce, nonce_count] = groups[1..2]
      # This algorithm is slow but easy to comprehend
      # Go through each bucket
      #   Work out how many nonces from the plot file are covered by the
      #   bucket and tally up the total for each bucket
      for bucket in BUCKETS
        bucket.consider  (Big first_nonce), (Big nonce_count)
    else
      throw "Unexpected form: #{file_name}"

  for bucket in BUCKETS
    p  bucket.toString()



chart = null  # scope



render = ->
  # Find the bucket containing the most nonces.  It will be the "hottest"
  emptiest_bucket = BUCKETS[0]
  fullest_bucket = BUCKETS[0]
  for bucket in BUCKETS
    emptiest_bucket = bucket if bucket.nonces.lt  emptiest_bucket.nonces
    fullest_bucket = bucket if bucket.nonces.gt  fullest_bucket.nonces
  range = fullest_bucket.nonces.plus( 1).minus  emptiest_bucket.nonces
  styler = (bucket, i)->
    # heat map
    scale = 360 * 2 / 3   # ends at blue
    intensity = Math.round  (bucket.nonces.minus  emptiest_bucket.nonces).times(scale).div  range
    color = new HSV  0.01 + scale - intensity, 75, 90
    rgb = ColorConverter.toRGB  color
    to_hex = (n)->
      n = n.toString 16
      n = "0"+n if n.length is 1
      n
    "#"+ [rgb.r, rgb.g, rgb.b].map( to_hex).join ''
  chart.show  BUCKETS, styler



$(document).ready ->

  button = $ '#button'
  input = $ '#input'
  textarea = input.find 'textarea'
  viewport_width = document.body.clientWidth
  viewport_height = document.documentElement.clientHeight
  attributes =
    width: viewport_width
    height: viewport_height
  canvas_element = elm 'canvas', attributes
  ($ '#canvas_box').append  canvas_element
  canvas = $ canvas_element
  chart = new ArcChart canvas_element

  # When the button is clicked, it should be replaced with the <textarea> and
  # instructions
  button.click ->
    button.fadeOut 'fast'
    input.fadeIn 'fast'

  # Testing:
  #button.trigger 'click'

  # Input should be parsed when it is pasted in to the <textarea>
  textarea.on 'input', ->
    parse  textarea.val()
    render()
    input.fadeOut 'fast'
    canvas.fadeIn 'fast'

