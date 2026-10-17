-- Pixel sprites for towers, in the style of the terrain tiles (3/4 view, light from the top
-- left). So far: the Mountain repair workshop (sketch C3), plus the other sketches it was
-- picked from.
--
-- Each building is built in a small height model like the HQ castle in terrain_tiles.lua: every
-- ground pixel may carry a column (face material up to `wall`, roof above it), drawn back to
-- front; pipes, cranes, smoke and sparks are painted on afterwards.
--
-- Game sprites (`final`): yard and building on a transparent 56×96 canvas aligned like the
-- terrain tiles, saved as PNG plus an .aseprite file with the layers "yard" and "building".
-- Sketches (`out`): every sketch on a mountain tile (`tile`), with an optional `preview` sheet.
-- Run:
--   Aseprite.exe -b --script-param final=assets/art/towers --script tools/aseprite/tower_sprites.lua
--   Aseprite.exe -b --script-param out=<folder> --script-param preview=<png> --script tools/aseprite/tower_sprites.lua

local FINAL = app.params.final
local OUT = app.params.out
local TILE = app.params.tile or "assets/art/terrain/hexHighlands00.png"
local PREVIEW = app.params.preview

local W, H = 56, 96
local CX, CY = 28, 64

-- --- colour and noise helpers (as in terrain_tiles.lua) ---------------------------------

local function hex(s)
	return { tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16) }
end

local function palette(list)
	local p = {}
	for i, s in ipairs(list) do p[i] = hex(s) end
	return p
end

local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }

local function dither(pal, v, x, y)
	local n = #pal
	local s = math.max(0, math.min(0.9999, v)) * (n - 1)
	local i = math.floor(s)
	if s - i > (BAYER[(y % 4) * 4 + (x % 4) + 1] + 0.5) / 16 then i = math.min(i + 1, n - 1) end
	return pal[i + 1]
end

local function mix(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] }
end

local function hash(x, y, s)
	local n = math.floor(x) * 374761393 + math.floor(y) * 668265263 + s * 1442695041
	n = (n ~ (n >> 13)) * 1274126177
	n = n ~ (n >> 16)
	return (n & 0xffffff) / 0xffffff
end

-- --- palettes ---------------------------------------------------------------------------

local STONE = palette { "2a2a2e", "38383d", "47474c", "57575c", "68686c", "7a797c", "8d8b8c", "a19e9c", "b6b2ad", "cbc6bf" }
local METAL = palette { "171a21", "232832", "313845", "414a59", "535e6f", "687486", "7f8b9d", "99a4b4", "b6becb", "d5dae2" }
local COPPER = palette { "3e1a0e", "6a3018", "974a24", "c06a34", "e09450" }
local GLASS = palette { "16202c", "223448", "34506a", "4f7490" }
local GLOW = palette { "5e3410", "b8661c", "ffb03c", "fff0a0" }
-- Warmer materials so the building stands out from the grey mountain ground.
local SANDSTONE = palette { "3a2f27", "4d3f33", "625140", "79654f", "917a60", "aa9274", "c2aa8a", "d8c3a3" }
local RUST_ROOF = palette { "3a1610", "5e2416", "86361c", "ad4c24", "cc6a32", "e48a48" }
local BRASS = palette { "3e220c", "6c4016", "9c6424", "c08236", "d89e50", "e8c27c" }
local HAZARD = palette { "5a4410", "a07c18", "dcb028", "f4d64e" }
local WOOD = palette { "33200f", "4f331b", "6e4a28", "8f6536" }
local SMOKE = palette { "b4b4ba", "84848c" }
local DARK = hex "121318"

-- --- pixel buffers ----------------------------------------------------------------------

local function buffer() return { px = {} } end

local function get(b, x, y)
	if x < 0 or y < 0 or x >= W or y >= H then return nil end
	return b.px[y * W + x]
end

local function put(b, x, y, c)
	x, y = math.floor(x), math.floor(y)
	if x < 0 or y < 0 or x >= W or y >= H then return end
	b.px[y * W + x] = c
end

local function line(b, x0, y0, x1, y1, c)
	local n = math.max(math.abs(x1 - x0), math.abs(y1 - y0))
	for i = 0, n do
		local t = n == 0 and 0 or i / n
		put(b, math.floor(x0 + (x1 - x0) * t + 0.5), math.floor(y0 + (y1 - y0) * t + 0.5), c)
	end
end

-- --- height model ------------------------------------------------------------------------
-- A column: h (top), wall (roof starts above), nx (-1 faces the light … +1 faces away),
-- face/roof (palettes), plinth (stone below this height), tex ("ashlar", "panel", "plain"),
-- rtex ("corrugated", "glass", "plain").

local function new_model()
	local cols = {}
	local m = {}

	local function set(x, y, c)
		if x < 0 or x >= W or y < 0 or y >= H then return end
		local old = cols[y * W + x]
		if not old or c.h > old.h then cols[y * W + x] = c end
	end

	function m.height(x, y)
		local c = cols[y * W + x]
		return c and c.h or 0
	end

	-- Box with an optional roof: "flat", "gable" (ridge along x), "saw" (sawtooth with glass
	-- strips facing the viewer, `period` rows per tooth).
	function m.box(x0, y0, x1, y1, o)
		local wall, rh = o.wall, o.roof_h or 0
		for y = y0, y1 do
			for x = x0, x1 do
				local extra, rtex = 0, o.rtex or "corrugated"
				if o.roof == "gable" then
					local half = (y1 - y0) / 2
					extra = rh * (1 - math.abs(y - (y0 + y1) / 2) / (half + 0.5))
				elseif o.roof == "saw" then
					local f = ((y - y0) % o.period) / o.period
					extra = rh * (1 - f)
					if (y - y0) % o.period == o.period - 1 then rtex = "glass" end
				end
				local nx = (x - (x0 + x1) / 2) / (x1 - x0) * 1.6
				set(x, y, { h = wall + extra, wall = wall, nx = nx, face = o.face or STONE, roof = o.roof_pal or METAL,
					base = o.base or STONE, plinth = o.plinth or 0, tex = o.tex or "ashlar", rtex = rtex })
			end
		end
	end

	-- Upright cylinder; roof "cone", "dome" or "flat".
	function m.cylinder(cx, cy, r, o)
		for y = math.floor(cy - r - 1), math.ceil(cy + r + 1) do
			for x = math.floor(cx - r - 1), math.ceil(cx + r + 1) do
				local dx, dy = x + 0.5 - cx, (y + 0.5 - cy) * 1.25
				local d = math.sqrt(dx * dx + dy * dy)
				if d <= r then
					local extra = 0
					if o.roof == "cone" then extra = (o.roof_h or 0) * (1 - d / r)
					elseif o.roof == "dome" then extra = (o.roof_h or 0) * math.sqrt(math.max(0, 1 - (d / r) ^ 2)) end
					set(x, y, { h = o.wall + extra, wall = o.wall, nx = dx / r, face = o.face or STONE, roof = o.roof_pal or METAL,
						base = o.base or STONE, plinth = o.plinth or 0, tex = o.tex or "ashlar", rtex = o.rtex or "plain" })
				end
			end
		end
	end

	-- Draws the columns back to front into `d`, casting shadows onto `g`.
	function m.render(g, d)
		for y = 0, H - 1 do
			for x = 0, W - 1 do
				if get(g, x, y) then
					for t = 1, 16 do
						local sx, sy = x - t, math.floor(y - t * 0.5)
						if sx >= 0 and sy >= 0 and m.height(sx, sy) > t * 0.9 then
							local c = get(g, x, y)
							put(g, x, y, { c[1] * 0.62, c[2] * 0.64, c[3] * 0.7 })
							break
						end
					end
				end
			end
		end
		for y = 0, H - 1 do
			for x = 0, W - 1 do
				local c = cols[y * W + x]
				if c then
					local top = math.floor(c.h + 0.5)
					local slope = (m.height(x + 1, y) - m.height(x - 1, y)) + (m.height(x, y + 1) - m.height(x, y - 1))
					for k = 0, top do
						local sy = y - k
						local col
						if k > c.wall then
							if c.rtex == "glass" and k < top then
								col = dither(GLASS, 0.5 - c.nx * 0.2, x, sy)
								if hash(x, sy, 3) > 0.7 then col = GLOW[2] end
							else
								local v = 0.55 - c.nx * 0.3 - slope * 0.05
								if c.rtex == "corrugated" and x % 2 == 0 then v = v - 0.1 end
								col = dither(c.roof, v, x, sy)
							end
						elseif k == top then
							col = dither(c.face, 0.78 - c.nx * 0.1, x, sy)
						else
							local pal = k < c.plinth and c.base or c.face
							local tex = k < c.plinth and "ashlar" or c.tex
							local v = 0.5 - c.nx * 0.3 + k / math.max(c.wall, 1) * 0.1
							if tex == "ashlar" then
								if sy % 3 == 0 or (x + (sy // 3) % 2 * 3) % 5 == 0 then v = v - 0.12 end
							elseif tex == "panel" then
								if x % 5 == 0 then v = v - 0.12 elseif x % 5 == 1 and sy % 4 == 0 then v = v + 0.2 end
							end
							if k == c.plinth and c.plinth > 0 then v = v + 0.15 end
							col = dither(pal, v, x, sy)
							if tex == "hazard" and (sy // 2) % 2 == 1 then col = dither(METAL, v - 0.3, x, sy) end
						end
						put(d, x, sy, col)
					end
				end
			end
		end
	end

	return m
end

-- --- painted details ----------------------------------------------------------------------

-- Workshop door with firelight inside and sparks flying out.
local function door(d, x0, ground, w, h, s)
	for k = 0, h - 1 do
		for x = x0, x0 + w - 1 do
			local arch = k == h - 1 and (x == x0 or x == x0 + w - 1)
			if not arch then put(d, x, ground - k, k < 2 and GLOW[2 + (k == 0 and 1 or 0)] or DARK) end
		end
	end
	for i = 1, 5 do
		local sx = x0 + math.floor(hash(i, 1, s) * (w + 4)) - 2
		local sy = ground - h - math.floor(hash(i, 2, s) * 4)
		put(d, sx, sy, GLOW[hash(i, 3, s) > 0.5 and 4 or 3])
	end
end

local function smoke(d, x, y, s)
	for i = 0, 3 do
		local cx, cy, r = x + i * 1.5 + hash(i, 1, s) * 2, y - i * 3, 1.3 + i * 0.4
		for yy = -2, 2 do
			for xx = -2, 3 do
				local px, py = math.floor(cx + xx), math.floor(cy + yy)
				if xx * xx + yy * yy <= r * r and not get(d, px, py) then
					put(d, px, py, (xx + yy < 0) and SMOKE[1] or SMOKE[2])
				end
			end
		end
	end
end

-- Brass cog on a wall: a rim with eight teeth, four spokes and a hub with a dark axle; the
-- gaps between the spokes stay open so the wall shows through.
local function cog(d, cx, cy, r)
	local n = math.ceil(r) + 2
	for yy = -n, n do
		for xx = -n, n do
			local dist = math.sqrt(xx * xx + yy * yy)
			local a = math.atan(yy, xx)
			local tooth = (a / (2 * math.pi) * 8) % 1 < 0.45
			local rim = dist > r - 1.2 and dist <= r + 0.3
			local spoke = dist <= r and math.abs(math.sin(2 * a)) < 0.3
			local hub = dist <= 1.6
			if rim or spoke or hub or (tooth and dist > r and dist <= r + 1.5) then
				local c
				if dist <= 0.8 then
					c = METAL[2]
				else
					c = dither(BRASS, 0.62 - (xx + yy) / (r + 1) * 0.35, cx + xx, cy + yy)
				end
				put(d, cx + xx, cy + yy, c)
			end
		end
	end
end

-- Pipe in screen space: lit top line, dark bottom line.
local function pipe(d, x0, y0, x1, y1)
	line(d, x0, y0, x1, y1, METAL[7])
	line(d, x0, y0 + 1, x1, y1 + 1, METAL[3])
end

-- A paved stone yard over the middle of the tile, so the workshop stands on clean ground.
local function yard(g)
	local inset = 24
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local px, py = x + 0.5 - CX, y + 0.5 - CY
			if math.abs(px) <= 0.866 * inset and math.abs(py) <= inset - math.abs(px) / 1.732 then
				local edge = math.abs(px) > 0.866 * inset - 1 or math.abs(py) > inset - math.abs(px) / 1.732 - 1
				local slab = (y % 4 == 0) or ((x + (y // 4) % 2 * 3) % 6 == 0)
				local v = 0.55 - (px + py) * 0.004 + (hash(x // 6, y // 4, 9) - 0.5) * 0.12
				if slab then v = v - 0.15 end
				put(g, x, y, edge and ((x + y) % 4 == 0 and METAL[8] or METAL[3]) or dither(STONE, v, x, y))
			end
		end
	end
end

-- Soft dark outline on the lower and right edges of the silhouette.
local function outline(d)
	local edge = {}
	for i, c in pairs(d.px) do
		local x, y = i % W, i // W
		if (c[4] or 255) == 255 and (not get(d, x + 1, y) or not get(d, x, y + 1)) then
			edge[#edge + 1] = { x, y, mix(c, DARK, 0.5) }
		end
	end
	for _, e in ipairs(edge) do put(d, e[1], e[2], e[3]) end
end

-- --- the three sketches --------------------------------------------------------------------

-- A: stone hall with a sawtooth roof of metal and glowing glass strips, a tall stone chimney
-- and a small water tank.
local function hall(g, d)
	local m = new_model()
	yard(g)
	m.box(15, 56, 40, 70, { wall = 8, plinth = 4, face = METAL, tex = "panel", roof = "saw", roof_h = 4, period = 5 })
	m.cylinder(37, 54, 2.2, { wall = 21, plinth = 17, face = STONE, tex = "ashlar", roof = "flat" })
	m.cylinder(11, 69, 3.2, { wall = 7, face = METAL, tex = "panel", roof = "dome", roof_h = 2 })
	m.render(g, d)
	door(d, 22, 70, 7, 5, 1)
	-- Metal band on the chimney and a pipe from the tank into the hall.
	for x = 35, 39 do put(d, x, 54 - 17 + 1, METAL[6]) end
	pipe(d, 13, 64, 15, 64)
	cog(d, 35, 63, 4)
	smoke(d, 37, 30, 4)
	outline(d)
end

-- B: round stone forge with metal upper storey and a low metal cap, a hot chimney stack in the
-- middle, two pressure tanks joined by pipes.
local function forge(g, d)
	local m = new_model()
	yard(g)
	m.cylinder(28, 62, 9, { wall = 11, plinth = 5, face = METAL, tex = "panel", roof = "cone", roof_h = 5 })
	m.cylinder(28, 61, 2.2, { wall = 21, face = METAL, tex = "panel", roof = "flat" })
	m.cylinder(13, 71, 3.4, { wall = 7, face = METAL, tex = "panel", roof = "dome", roof_h = 2 })
	m.cylinder(43, 71, 3.4, { wall = 7, face = METAL, tex = "panel", roof = "dome", roof_h = 2 })
	m.render(g, d)
	door(d, 25, 69, 6, 5, 2)
	pipe(d, 16, 64, 20, 61)
	pipe(d, 40, 64, 36, 61)
	cog(d, 20, 61, 4)
	put(d, 28, 61 - 21 - 1, GLOW[3])
	put(d, 27, 61 - 21 - 1, GLOW[2])
	smoke(d, 28, 33, 5)
	outline(d)
end

-- C: low sandstone workshop under a rusty corrugated gable roof, crates in the yard; the
-- crane is added by the two variants below.
local function workshop(g, m)
	yard(g)
	m.box(12, 53, 32, 64, { wall = 8, plinth = 2, face = SANDSTONE, roof = "gable", roof_h = 5, roof_pal = RUST_ROOF, tex = "ashlar" })
	m.cylinder(16, 55, 1.6, { wall = 15, plinth = 15, base = SANDSTONE, roof = "flat" })
	m.box(14, 69, 17, 72, { wall = 3, face = WOOD, tex = "panel", roof = "flat" })
	m.box(18, 71, 20, 73, { wall = 2, face = WOOD, tex = "panel", roof = "flat" })
end

local function workshop_details(d)
	door(d, 19, 64, 6, 5, 3)
	cog(d, 28, 58, 4)
	smoke(d, 16, 37, 6)
end

-- C1: a yellow gantry crane over the yard lifting a girder.
local function gantry(g, d)
	local m = new_model()
	workshop(g, m)
	local BEAM = 13
	for _, lx in ipairs({ 30, 46 }) do m.box(lx, 74, lx + 1, 74, { wall = BEAM, face = HAZARD, tex = "hazard", roof = "flat" }) end
	m.box(37, 77, 39, 78, { wall = 2, face = METAL, tex = "plain", roof = "flat" })
	m.render(g, d)
	workshop_details(d)
	local top = 74 - BEAM
	line(d, 30, top - 1, 47, top - 1, HAZARD[4])
	line(d, 30, top, 47, top, HAZARD[3])
	line(d, 30, top + 1, 47, top + 1, HAZARD[1])
	-- Trolley, chain and a hanging girder.
	put(d, 38, top - 2, METAL[6])
	put(d, 39, top - 2, METAL[4])
	line(d, 38, top + 2, 38, top + 6, METAL[3])
	line(d, 34, top + 7, 42, top + 7, METAL[8])
	line(d, 34, top + 8, 42, top + 8, METAL[4])
	outline(d)
end

-- C2: a yellow jib crane beside the workshop: a striped mast with a cab, the jib reaching over
-- the yard to a hook with a load, a short counter-jib with a stone counterweight.
local function jib(g, d)
	local m = new_model()
	workshop(g, m)
	local MX, MY, MH = 41, 65, 18
	m.box(MX, MY - 1, MX + 1, MY, { wall = MH, face = HAZARD, tex = "hazard", roof = "flat" })
	m.box(28, 73, 32, 74, { wall = 2, face = METAL, tex = "plain", roof = "flat" })
	m.render(g, d)
	workshop_details(d)
	local top = MY - MH
	-- Jib: a horizontal lattice reaching left over the yard, a short counter-jib to the right
	-- with a stone counterweight.
	local hx = 29
	line(d, hx, top - 2, MX + 1, top - 2, HAZARD[4])
	line(d, hx, top + 1, MX + 1, top + 1, HAZARD[2])
	for x = hx, MX, 2 do
		put(d, x, top - 1, HAZARD[3])
		put(d, x + 1, top, HAZARD[3])
	end
	line(d, MX + 2, top - 2, MX + 7, top - 2, HAZARD[4])
	line(d, MX + 2, top - 1, MX + 7, top - 1, HAZARD[2])
	for x = MX + 5, MX + 8 do
		put(d, x, top, STONE[7])
		put(d, x, top + 1, STONE[4])
	end
	-- Cab with a lit window just below the jib.
	for y = top + 2, top + 4 do
		for x = MX - 1, MX + 2 do put(d, x, y, METAL[5]) end
	end
	put(d, MX, top + 3, GLOW[3])
	put(d, MX + 1, top + 3, GLOW[2])
	-- Trolley, cable, hook and a girder hanging just above the load.
	put(d, hx + 1, top + 2, METAL[6])
	line(d, hx + 1, top + 3, hx + 1, 66, METAL[2])
	put(d, hx + 1, 67, METAL[7])
	put(d, hx + 2, 68, METAL[7])
	line(d, hx - 3, 69, hx + 5, 69, METAL[8])
	line(d, hx - 3, 70, hx + 5, 70, METAL[4])
	outline(d)
end

-- C3: the workshop in the lower middle of the tile with a jib crane rising out of its roof,
-- a rail track across the yard in front with a cart under the hook, and a tank, crates and
-- barrels behind it.
local function crane_works(g, d)
	yard(g)
	-- Rails: two lit steel lines on wooden sleepers, running across the front of the yard.
	local R1, R2 = 78, 81
	for x = 10, 46 do
		if x % 3 == 0 then
			for y = R1 - 1, R2 + 1 do put(g, x, y, WOOD[2]) end
		end
		put(g, x, R1, METAL[8])
		put(g, x, R1 + 1, METAL[3])
		put(g, x, R2, METAL[8])
		put(g, x, R2 + 1, METAL[3])
	end
	local m = new_model()
	-- Behind the building: a water tank, crates and two rusty barrels.
	m.cylinder(15, 56, 2.8, { wall = 7, face = METAL, tex = "panel", roof = "dome", roof_h = 2 })
	m.box(9, 61, 12, 64, { wall = 3, face = WOOD, tex = "panel", roof = "flat" })
	m.box(10, 65, 13, 67, { wall = 2, face = WOOD, tex = "panel", roof = "flat" })
	m.cylinder(44, 60, 2, { wall = 3, face = RUST_ROOF, tex = "plain", roof = "flat" })
	m.cylinder(46, 64, 2, { wall = 3, face = RUST_ROOF, tex = "plain", roof = "flat" })
	-- The workshop, centred low on the tile, with a chimney at its back.
	m.box(17, 61, 39, 72, { wall = 8, plinth = 2, face = SANDSTONE, roof = "gable", roof_h = 5, roof_pal = RUST_ROOF, tex = "ashlar" })
	m.cylinder(29, 62, 1.6, { wall = 17, roof = "flat" })
	-- Crane mast rising out of the roof (back left), and the cart on the rails.
	local MX, MY, MH = 21, 63, 22
	m.box(MX, MY, MX + 1, MY, { wall = MH, face = HAZARD, tex = "hazard", roof = "flat" })
	m.box(33, R1 - 1, 38, R2, { wall = 3, face = METAL, tex = "panel", roof = "flat" })
	m.render(g, d)

	door(d, 25, 72, 6, 5, 3)
	cog(d, 35, 67, 3)
	smoke(d, 29, 42, 6)
	-- Jib to the right over the roof, counter-jib to the left with its counterweight.
	local top = MY - MH
	local hx = 36
	line(d, MX, top - 2, hx + 1, top - 2, HAZARD[4])
	line(d, MX, top + 1, hx + 1, top + 1, HAZARD[2])
	for x = MX, hx, 2 do
		put(d, x, top - 1, HAZARD[3])
		put(d, x + 1, top, HAZARD[3])
	end
	line(d, MX - 6, top - 2, MX - 1, top - 2, HAZARD[4])
	line(d, MX - 6, top - 1, MX - 1, top - 1, HAZARD[2])
	for x = MX - 7, MX - 4 do
		put(d, x, top, STONE[7])
		put(d, x, top + 1, STONE[4])
	end
	-- Cab below the jib.
	for y = top + 2, top + 4 do
		for x = MX - 1, MX + 2 do put(d, x, y, METAL[5]) end
	end
	put(d, MX, top + 3, GLOW[3])
	put(d, MX + 1, top + 3, GLOW[2])
	-- Trolley, cable down past the roof to a girder hanging over the cart.
	put(d, hx, top + 2, METAL[6])
	local load = R1 - 3 - 3
	line(d, hx, top + 3, hx, load - 3, METAL[2])
	put(d, hx, load - 2, METAL[7])
	put(d, hx + 1, load - 1, METAL[7])
	line(d, hx - 4, load, hx + 4, load, METAL[8])
	line(d, hx - 4, load + 1, hx + 4, load + 1, METAL[4])
	outline(d)
end

-- --- saving ---------------------------------------------------------------------------------

local function to_image(b)
	local img = Image(W, H, ColorMode.RGB)
	img:clear(0)
	for i, c in pairs(b.px) do
		img:drawPixel(i % W, i // W, app.pixelColor.rgba(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5), c[4] or 255))
	end
	return img
end

local function load_tile()
	local img = Image { fromFile = TILE }
	local b = buffer()
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local p = img:getPixel(x, y)
			local a = app.pixelColor.rgbaA(p)
			if a > 0 then put(b, x, y, { app.pixelColor.rgbaR(p), app.pixelColor.rgbaG(p), app.pixelColor.rgbaB(p) }) end
		end
	end
	return b
end

-- Game sprites: name -> building function.
local SPRITES = { { "mountainRepair", crane_works } }
if FINAL then
	app.fs.makeAllDirectories(FINAL .. "/src")
	for _, sp in ipairs(SPRITES) do
		local g, d = buffer(), buffer()
		sp[2](g, d)
		local spr = Sprite(W, H, ColorMode.RGB)
		spr.layers[1].name = "yard"
		spr:newCel(spr.layers[1], 1, to_image(g), Point(0, 0))
		local layer = spr:newLayer()
		layer.name = "building"
		spr:newCel(layer, 1, to_image(d), Point(0, 0))
		spr:saveAs(FINAL .. "/src/" .. sp[1] .. ".aseprite")
		spr:saveCopyAs(FINAL .. "/" .. sp[1] .. ".png")
		spr:close()
	end
end

if not OUT then return end
app.fs.makeAllDirectories(OUT .. "/src")
local SKETCHES = { { "mountainRepairA", hall }, { "mountainRepairB", forge }, { "mountainRepairC1", gantry }, { "mountainRepairC2", jib }, { "mountainRepairC3", crane_works } }
local flat = {}
for i, sk in ipairs(SKETCHES) do
	local g, d = load_tile(), buffer()
	sk[2](g, d)
	local spr = Sprite(W, H, ColorMode.RGB)
	spr.layers[1].name = "ground"
	spr:newCel(spr.layers[1], 1, to_image(g), Point(0, 0))
	local layer = spr:newLayer()
	layer.name = "building"
	spr:newCel(layer, 1, to_image(d), Point(0, 0))
	spr:saveAs(OUT .. "/src/" .. sk[1] .. ".aseprite")
	spr:close()
	-- The building alone, for the game.
	local only = Sprite(W, H, ColorMode.RGB)
	only:newCel(only.layers[1], 1, to_image(d), Point(0, 0))
	only:saveCopyAs(OUT .. "/" .. sk[1] .. ".png")
	only:close()
	flat[i] = { g, d }
end

if PREVIEW then
	local SCALE, GAP = 5, 6
	local PW = (#SKETCHES * (W + GAP) + GAP) * SCALE
	local img = Image(PW, H * SCALE, ColorMode.RGB)
	img:clear(app.pixelColor.rgba(26, 34, 54, 255))
	for i, pair in ipairs(flat) do
		local ox = GAP + (i - 1) * (W + GAP)
		for y = 0, H - 1 do
			for x = 0, W - 1 do
				local c = pair[1].px[y * W + x]
				local top = pair[2].px[y * W + x]
				if top then
					local a = (top[4] or 255) / 255
					c = c and mix(c, top, a) or (a > 0.5 and top or nil)
				end
				if c then
					local col = app.pixelColor.rgba(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5), 255)
					for yy = 0, SCALE - 1 do
						for xx = 0, SCALE - 1 do img:drawPixel((ox + x) * SCALE + xx, y * SCALE + yy, col) end
					end
				end
			end
		end
	end
	local spr = Sprite(PW, H * SCALE, ColorMode.RGB)
	spr:newCel(spr.layers[1], 1, img, Point(0, 0))
	spr:saveCopyAs(PREVIEW)
	spr:close()
end
