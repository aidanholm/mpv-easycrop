local msg = require('mp.msg')
local assdraw = require('mp.assdraw')

local script_name = "easycrop"

local points = {}

-- Helper that converts two points to top-left and bottom-right
local swizzle_points = function (p1, p2)
    if p1.x > p2.x then p1.x, p2.x = p2.x, p1.x end
    if p1.y > p2.y then p1.y, p2.y = p2.y, p1.y end
end

-- Wrapper that converts RRGGBB / RRGGBBAA to ASS format
local ass_set_color = function (idx, color)
    assert(color:len() == 8 or color:len() == 6)
    local ass = ""

    -- Set alpha value (if present)
    if color:len() == 8 then
        local alpha = 0xff - tonumber(color:sub(7, 8), 16)
        ass = ass .. string.format("\\%da&H%X&", idx, alpha)
    end

    -- Swizzle RGB to BGR and build ASS string
    color = color:sub(5, 6) .. color:sub(3, 4) .. color:sub(1, 2)
    return "{" .. ass .. string.format("\\%dc&H%s&", idx, color) .. "}"
end

local draw_rect = function (p1, p2)
    local osd_w, osd_h = mp.get_property("osd-width"), mp.get_property("osd-height")

    ass = assdraw.ass_new()

    -- Draw overlay over surrounding unselected region

    ass:draw_start()
    ass:pos(0, 0)

    ass:append(ass_set_color(1, "000000aa"))
    ass:append(ass_set_color(3, "00000000"))

    local l = math.min(p1.x, p2.x)
    local r = math.max(p1.x, p2.x)
    local u = math.min(p1.y, p2.y)
    local d = math.max(p1.y, p2.y)

    ass:rect_cw(0, 0, l, osd_h)
    ass:rect_cw(r, 0, osd_w, osd_h)
    ass:rect_cw(l, 0, r, u)
    ass:rect_cw(l, d, r, osd_h)

    ass:draw_stop()

    -- Draw border around selected region

    ass:new_event()
    ass:draw_start()
    ass:pos(0, 0)

    ass:append(ass_set_color(1, "00000000"))
    ass:append(ass_set_color(3, "000000ff"))
    ass:append("{\\bord2}")

    ass:rect_cw(p1.x, p1.y, p2.x, p2.y)

    ass:draw_stop()

    mp.set_osd_ass(osd_w, osd_h, ass.text)
end

local draw_clear = function ()
    local osd_w, osd_h = mp.get_property("osd-width"), mp.get_property("osd-height")
    mp.set_osd_ass(osd_w, osd_h, "")
end

local draw_cropper = function ()
    if #points == 1 then
        local p2 = {}
        p2.x, p2.y = mp.get_mouse_pos()
        draw_rect(points[1], p2)
    end
end

local uncrop = function ()
    mp.command("no-osd vf del @" .. script_name .. ":crop")
end

local crop = function(p1, p2)
    swizzle_points(p1, p2)

    -- Video native dimensions
    local vid_w = mp.get_property("width")
    local vid_h = mp.get_property("height")

    -- Screen size
    local osd_w = mp.get_property("osd-width")
    local osd_h = mp.get_property("osd-height")

    -- Factor by which the video is scaled to fit the screen
    local scale = math.min(osd_w/vid_w, osd_h/vid_h)

    -- Size video takes up in screen
    local vid_sw, vid_sh = scale*vid_w, scale*vid_h

    -- Video offset within screen
    local off_x = math.floor((osd_w - vid_sw)/2)
    local off_y = math.floor((osd_h - vid_sh)/2)

    -- Convert screen-space to video-space
    p1.x = math.floor((p1.x - off_x) / scale)
    p1.y = math.floor((p1.y - off_y) / scale)
    p2.x = math.floor((p2.x - off_x) / scale)
    p2.y = math.floor((p2.y - off_y) / scale)

    local w = p2.x - p1.x
    local h = p2.y - p1.y
    local ok, err = mp.command(string.format(
        "no-osd vf add @%s:crop=%s:%s:%s:%s", script_name, w, h, p1.x, p1.y))

    if not ok then
        mp.osd_message("Cropping failed")
        points = {}
    end
end

local file_loaded_cb = function ()
    mp.add_key_binding("mouse_btn0", function ()
        local mx, my = mp.get_mouse_pos()
        table.insert(points, { x = mx, y = my })
        if #points == 2 then
            crop(points[1], points[2])
            draw_clear()
        elseif #points == 3 then
            points = {}
            uncrop()
        end
    end)
end

-- Redraw the selection filter on window resize or mouse move
mp.add_key_binding("mouse_move", draw_cropper)
mp.observe_property("osd-width", "native", draw_cropper)
mp.observe_property("osd-height", "native", draw_cropper)

mp.register_event('file-loaded', file_loaded_cb)
