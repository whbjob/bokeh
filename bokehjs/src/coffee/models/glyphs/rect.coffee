_ = require "underscore"

Glyph = require "./glyph"
hittest = require "../../core/hittest"
p = require "../../core/properties"

class RectView extends Glyph.View

  _set_data: () ->
    @max_w2 = 0
    if @model.properties.width.units == "data"
      @max_w2 = @max_width/2
    @max_h2 = 0
    if @model.properties.height.units == "data"
      @max_h2 = @max_height/2

  _index_data: () ->
    @_xy_index()

  _map_data: () ->
    if @model.properties.width.units == "data"
      @sw = @sdist(@renderer.xmapper, @_x, @_width, 'center', @model.dilate)
    else
      @sw = @_width
    if @model.properties.height.units == "data"
      @sh = @sdist(@renderer.ymapper, @_y, @_height, 'center', @model.dilate)
    else
      @sh = @_height

  _render: (ctx, indices, {sx, sy, sw, sh, _angle}) ->
    if @visuals.fill.doit
      for i in indices
        if isNaN(sx[i]+sy[i]+sw[i]+sh[i]+_angle[i])
          continue

        #no need to test the return value, we call fillRect for every glyph anyway
        @visuals.fill.set_vectorize(ctx, i)

        if _angle[i]
          ctx.translate(sx[i], sy[i])
          ctx.rotate(_angle[i])
          ctx.fillRect(-sw[i]/2, -sh[i]/2, sw[i], sh[i])
          ctx.rotate(-_angle[i])
          ctx.translate(-sx[i], -sy[i])
        else
          ctx.fillRect(sx[i]-sw[i]/2, sy[i]-sh[i]/2, sw[i], sh[i])

    if @visuals.line.doit
      ctx.beginPath()

      for i in indices

        if isNaN(sx[i] + sy[i] + sw[i] + sh[i] + _angle[i])
          continue

        # fillRect does not fill zero-height or -width rects, but rect(...)
        # does seem to stroke them (1px wide or tall). Explicitly ignore rects
        # with zero width or height to be consistent
        if sw[i]==0 or sh[i]==0
          continue

        if _angle[i]
          ctx.translate(sx[i], sy[i])
          ctx.rotate(_angle[i])
          ctx.rect(-sw[i]/2, -sh[i]/2, sw[i], sh[i])
          ctx.rotate(-_angle[i])
          ctx.translate(-sx[i], -sy[i])
        else
          ctx.rect(sx[i]-sw[i]/2, sy[i]-sh[i]/2, sw[i], sh[i])

        @visuals.line.set_vectorize(ctx, i)
        ctx.stroke()
        ctx.beginPath()

      ctx.stroke()

  _hit_rect: (geometry) ->
    [x0, x1] = @renderer.xmapper.v_map_from_target([geometry.vx0, geometry.vx1], true)
    [y0, y1] = @renderer.ymapper.v_map_from_target([geometry.vy0, geometry.vy1], true)
    bbox = hittest.validate_bbox_coords([x0, x1], [y0, y1])
    result = hittest.create_hit_test_result()
    result['1d'].indices = (x.i for x in @index.search(bbox))
    return result

  _hit_point: (geometry) ->
    [vx, vy] = [geometry.vx, geometry.vy]
    x = @renderer.xmapper.map_from_target(vx, true)
    y = @renderer.ymapper.map_from_target(vy, true)

    # the dilation by a factor of two is a quick and easy way to make
    # sure we cover cases with rotated
    if @model.properties.width.units == "screen"
      vx0 = vx - 2*@max_width
      vx1 = vx + 2*@max_width
      [x0, x1] = @renderer.xmapper.v_map_from_target([vx0, vx1], true)
    else
      x0 = x - 2*@max_width
      x1 = x + 2*@max_width

    if @model.properties.height.units == "screen"
      vy0 = vy - 2*@max_height
      vy1 = vy + 2*@max_height
      [y0, y1] = @renderer.ymapper.v_map_from_target([vy0, vy1], true)
    else
      y0 = y - 2*@max_height
      y1 = y + 2*@max_height

    hits = []

    bbox = hittest.validate_bbox_coords([x0, x1], [y0, y1])
    for i in (pt.i for pt in @index.search(bbox))
      sx = @renderer.plot_view.canvas.vx_to_sx(vx)
      sy = @renderer.plot_view.canvas.vy_to_sy(vy)

      if @_angle[i]
        d = Math.sqrt(Math.pow((sx - @sx[i]), 2) + Math.pow((sy - @sy[i]),2))
        s = Math.sin(-@_angle[i])
        c = Math.cos(-@_angle[i])
        px = c * (sx-@sx[i]) - s * (sy-@sy[i]) + @sx[i]
        py = s * (sx-@sx[i]) + c * (sy-@sy[i]) + @sy[i]
        sx = px
        sy = py
      width_in = Math.abs(@sx[i]-sx) <= @sw[i]/2
      height_in = Math.abs(@sy[i]-sy) <= @sh[i]/2

      if height_in and width_in
        hits.push(i)

    result = hittest.create_hit_test_result()
    result['1d'].indices = hits
    return result

  draw_legend_for_index: (ctx, x0, x1, y0, y1, index) ->
    @_generic_area_legend(ctx, x0, x1, y0, y1, index)

  _bounds: (bds) ->
    return @max_wh2_bounds(bds)

class Rect extends Glyph.Model
  default_view: RectView

  type: 'Rect'

  @coords [['x', 'y']]
  @mixins ['line', 'fill']
  @define {
      angle:  [ p.AngleSpec,   0     ]
      width:  [ p.DistanceSpec       ]
      height: [ p.DistanceSpec       ]
      dilate: [ p.Bool,        false ]
    }

module.exports =
  Model: Rect
  View: RectView
