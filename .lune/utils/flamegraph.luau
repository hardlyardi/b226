local svg = require("./svg")

export type NodeMetadata = {
	fun: string,
	source: string,
	line: number,
	ticks: number,
}

export type Node = svg.Node<NodeMetadata>

local function svg_node(): Node
	local root_metadata: NodeMetadata = {
		fun = "",
		source = "",
		line = 0,
		ticks = 0,
	}
	return svg.node(root_metadata)
end

local function node_ensure_child(parent: Node, name: string): Node
	local children = parent.children
	local node = children[name]
	if not node then
		node = svg_node()
		node.name = name
		node.depth = parent.depth + 1
		children[name] = node
	end
	return node
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

local function graph_from_data(file_data: string): Node
	local root = svg_node()

	for _, raw_line in string.split(file_data, "\n") do
		if raw_line == "" then break end
		string.gsub(raw_line, "^ *", "")
		local ticks, stack = table.unpack(string.split(raw_line, " "))
		local node = root

		for _, stack_segment in table_reverse(string.split(stack, ";")) do
			if stack_segment == "" then break end
			local source, fun, line = table.unpack(string.split(stack_segment, ","))

			if line == "" then line = "0" end

			local child = node_ensure_child(node, fun)
			local metadata = child.metadata
			metadata.fun = fun
			metadata.source = source
			metadata.line = assert(tonumber(line))
			child.title = if metadata.line > 0 then `{fun},{source}:{metadata.line}` else fun
			child.text = fun

			node = child
		end

		node.metadata.ticks += assert(tonumber(ticks), ticks)
	end

	return root
end

local function svg_from_data(file_data: string, topdown: boolean, colors, title: string?): string
	local root = graph_from_data(file_data)

	local function details(node: Node): string
		local metadata = node.metadata
		local fun = metadata.fun
		local base = if fun ~= ""
			then `Fun '{fun}' [{metadata.source}:{metadata.line}]`
			else `[{metadata.source}:{metadata.line}]`
		return base
			.. string.format(
				"(%s usec, %.1f%%); self: %s usec",
				tostring(node.width):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""),
				(node.width / root.width) * 100,
				(tostring(metadata.ticks):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
			)
	end

	svg.layout(root, function(node: Node)
		return node.metadata.ticks
	end)
	return svg.render(root, title or "Luau Flamegraph", details, topdown, colors)
end

return {
	from_data = svg_from_data,
}
