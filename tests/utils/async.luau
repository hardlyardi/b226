local task = require("@lune/task")

local spawned_threads = {} :: { thread }

local async = setmetatable({
	await = function(): ()
		repeat
			for index = #spawned_threads, 1, -1 do
				if coroutine.status(spawned_threads[index]) == "dead" then
					table.remove(spawned_threads, index)
				end
			end
			task.wait()
		until #spawned_threads <= 0
	end,
}, {
	__call = function<Arguments..., Returns...>(self, fun: (Arguments...) -> Returns..., ...: Arguments...): thread
		local thread = task.spawn(fun, ...)
		table.insert(spawned_threads, thread)
		return thread
	end,
})

return async
