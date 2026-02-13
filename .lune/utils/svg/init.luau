local FNV_OFFSET_BASIS = 0x811c9dc5
local FNV_PRIME32 = 0x01000193
-- referenced from https://github.com/luau-lang/luau/blob/f3f3bf8f729967bd42d518a97773fb800d0191f9/tools/svg.py
local LEET30K = 31337
local FRAME_WIDTH = 1200 - 20
local BAR_HEIGHT_PX = 15
local TEXT_X_OFFSET = 3
local TEXT_Y_OFFSET = 10.5

local svg_template = require("@self/template")

export type Node<Metadata = unknown> = {
	name: string,
	text: string,
	title: string,
	children: { [string]: Node<Metadata> },
	depth: number,
	width: number,
	offset: number,
	metadata: Metadata,
}

local function exhaustive_match(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function node_create<Metadata>(metadata: Metadata): Node<Metadata>
	return {
		name = "",
		text = "",
		title = "",
		children = {},
		depth = 0,
		width = 0,
		offset = 0,
		metadata = metadata,
	}
end

local function node_subtree<Metadata>(node: Node<Metadata>): { Node<Metadata> }
	local graph: { Node<Metadata> } = { node }
	local graph_count = 1
	local index = 1

	while index <= graph_count do
		local subnode = graph[index]
		index += 1
		for _, child in subnode.children do
			graph_count += 1
			graph[graph_count] = child
		end
	end

	return graph
end

local function table_reverse<Values>(tbl: { Values }): { Values }
	local count = #tbl
	local swap_index = count
	for index = 1, count // 2 do
		tbl[index], tbl[swap_index] = tbl[swap_index], tbl[index]
		swap_index -= 1
	end
	return tbl
end

local function layout<Metadata>(root: Node<Metadata>, evaluate_width: (Node<Metadata>) -> number): ()
	local subtree = table_reverse(node_subtree(root))
	for _, node in subtree do
		local new_width = evaluate_width(node)
		local children = node.children
		local children_list = {}
		for _, child in children do
			new_width += child.width
			table.insert(children_list, child)
		end
		node.width = new_width

		table.sort(children_list, function(a: Node, b: Node): boolean
			return a.width > b.width
		end)
		local offset = 0
		for _, child in children_list do
			child.offset = offset
			offset += child.width
		end
	end

	for _, node in table_reverse(subtree) do
		local node_offset = node.offset
		for _, child in node.children do
			child.offset += node_offset
		end
	end
end

local function fnv1a_hash(input: string): number
	local hashed = FNV_OFFSET_BASIS
	-- I figure codepoints should be better than individual string bytes, although most probably won't hit 32 bits.
	for _, codepoint in utf8.codes(input) do
		hashed = bit32.bxor(hashed, codepoint)
		hashed *= FNV_PRIME32
		-- implicitly done by bit32 library
		-- hashed %= (2 ^ 32)
	end
	-- referenced from https://github.com/luau-lang/luau/blob/f3f3bf8f729967bd42d518a97773fb800d0191f9/tools/svg.py
	return (hashed % LEET30K) / LEET30K
end

local function escape(str: string): string
	str = string.gsub(str, "&", "&amp;")
	str = string.gsub(str, "<", "&lt;")
	str = string.gsub(str, ">", "&gt;")
	return str
end

local function pixels(x: number, root_width: number): number
	return if root_width ~= 0 then x / root_width * FRAME_WIDTH else 0
end

local function render<Metadata>(
	root: Node<Metadata>,
	title: string,
	details: (Node<Metadata>) -> string,
	topdown: boolean?,
	colors: ("cold" | "warm")?
): string
	colors = colors or ("warm" :: "warm")
	local gradient_start: string
	local gradient_end: string
	if colors == "cold" then
		gradient_start = "#ffffff"
		gradient_end = "#000000"
	elseif colors == "warm" then
		gradient_start = "#eeeeee"
		gradient_end = "#eeeeb0"
	else
		exhaustive_match(colors)
	end

	local root_subtree = node_subtree(root)
	local root_width = root.width

	local max_depth = 0
	for _, node in root_subtree do
		max_depth = math.max(max_depth, node.depth)
	end

	local svg_height = max_depth * 16 + 3 * 16 + 2 * 16

	local rendered_template = svg_template
	rendered_template = string.gsub(rendered_template, "$title", title)
	rendered_template = string.gsub(rendered_template, "$gradient%-start", gradient_start)
	rendered_template = string.gsub(rendered_template, "$gradient%-end", gradient_end)
	rendered_template = string.gsub(rendered_template, "$height", tostring(svg_height))
	rendered_template =
		string.gsub(rendered_template, "$status", tostring((svg_height - 16 + if topdown then 3 else 3 * 16 - 3)))
	rendered_template = string.gsub(rendered_template, "$flip", tostring(topdown and 1 or 0))

	for _, node in root_subtree do
		local width = pixels(node.width, root_width)
		if width < 0.1 then continue end
		if node == root then continue end

		local x = 10 + pixels(node.offset, root_width)
		local y = (if topdown then max_depth - 1 - node.depth else node.depth) * 16 + 3 * 16

		local node_name = node.name
		local fill_red: number, fill_green: number, fill_blue: number
		if colors == "cold" then
			fill_red = 0
			fill_green = math.floor(190 + 50 * fnv1a_hash(node_name))
			fill_blue = math.floor(210 * fnv1a_hash(string.reverse(node_name)))
		elseif colors == "warm" then
			fill_red = math.floor(205 + 50 * fnv1a_hash(node_name))
			fill_green = math.floor(230 * fnv1a_hash(string.reverse(node_name)))
			local half_removed = string.gsub(node_name, "(.).", "%1")
			fill_blue = math.floor(55 * fnv1a_hash(string.reverse(half_removed)))
		else
			exhaustive_match(colors)
		end

		local fill = `rgb({fill_red},{fill_green},{fill_blue})`
		local max_characters = width // (12 * 0.59)

		local text = node.text

		if max_characters >= 3 then
			if max_characters < #text then
				text = `{string.sub(text, 1, max_characters - 2)}..` --
			end
		else
			text = ""
		end

		rendered_template ..= "\n<g>"
		rendered_template ..= `\n<title>{node.title}</title>`
		rendered_template ..= `\n<details>{details(node)}</details>`
		rendered_template ..= `\n<rect x='{x}' y='{y}' width='{width}' height='{BAR_HEIGHT_PX}' fill='{fill}' rx='2' ry='2' />`
		rendered_template ..= `\n<text x='{x + TEXT_X_OFFSET}' y='{y + TEXT_Y_OFFSET}'>{escape(text)}</text>`
		rendered_template ..= `\n<rawtext>{escape(text)}</rawtext>`
		rendered_template ..= `\n</g>`
	end

	rendered_template ..= "\n</g>\n</svg>\n"

	return rendered_template
end

return {
	layout = layout,
	render = render,
	node = node_create,
}
