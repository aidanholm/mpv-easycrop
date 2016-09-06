local msg = require('mp.msg')
local assdraw = require('mp.assdraw')

local script_name = "easycrop"

local points = {}

local draw_rect = function (p1, p2)
    local osd_w, osd_h = mp.get_property("osd-width"), mp.get_property("osd-height")

    ass = assdraw.ass_new()
    ass:draw_start()
    ass:append(string.format("{\\1a&H%X&}", 0.1))
    ass:rect_cw(p1.x, p1.y, p2.x, p2.y)
    ass:pos(0, 0)
    ass:draw_stop()

    mp.set_osd_ass(osd_w, osd_h, ass.text)
end

local draw_clear = function ()
    local osd_w, osd_h = mp.get_property("osd-width"), mp.get_property("osd-height")
    mp.set_osd_ass(osd_w, osd_h, "")
end

local mouse_move_cb = function ()
    if #points == 1 then
        local p2 = {}
        p2.x, p2.y = mp.get_mouse_pos()
        draw_rect(points[1], p2)
    end
end

local crop = function(p1, p2)
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

    local w = math.abs(p1.x - p2.x)
    local h = math.abs(p1.y - p2.y)
    local x = math.min(p1.x, p2.x)
    local y = math.min(p1.y, p2.y)
    mp.command(string.format("vf add @%s:crop=%s:%s:%s:%s", easy_crop, w, h, x, y))
end

local file_loaded_cb = function ()
    mp.add_key_binding("mouse_btn0", function ()
        local mx, my = mp.get_mouse_pos()
        table.insert(points, { x = mx, y = my })
        if #points == 2 then
            crop(points[1], points[2])
            draw_clear()
            points = {}
        end
    end)
    mp.add_key_binding("mouse_move", mouse_move_cb)
end

mp.register_event('file-loaded', file_loaded_cb)
