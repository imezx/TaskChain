--!optimize 2
local TaskChain = {}
TaskChain.__index = TaskChain

local types = require(script.Types)

--]
local function _processNextTask(self: types.TaskChain)
	if self._status == "Destroyed" or not self._isProcessing then
		return
	end

	if #self._tasks == 0 then
		self._isProcessing = false
		return
	end

	local taskDescriptor = table.remove(self._tasks, 1)

	self._promise = self._promise:andThen(function(...)
		if self._status == "Destroyed" then
			return types.promise
				.new(function(_, _, onCancel)
					onCancel(function()
						return
					end)
				end)
				:cancel()
		end

		local results = { ... }
		local taskType = taskDescriptor.type
		local payload = taskDescriptor.payload
		if taskType == "call" then
			return payload.func(table.unpack(results), table.unpack(payload.args))
		elseif taskType == "wait" then
			local waitPromise = types.promise.delay(payload.duration)
			self._janitor:Add(waitPromise, "cancel")
			return waitPromise:andThen(function()
				return table.unpack(results)
			end)
		elseif taskType == "promise" then
			self._janitor:Add(payload.promise, "cancel")
			return payload.promise
		elseif taskType == "andThen" then
			local p = types.promise.resolve(table.unpack(results))
			return p:andThen(payload.onSuccess, payload.onFailure)
		elseif taskType == "track" then
			self._janitor:Add(payload.item, payload.cleanupMethod)
			return table.unpack(results)
		elseif taskType == "catch" or taskType == "finally" then
			return table.unpack(results)
		end
	end)
	_processNextTask(self)
end

--]
function TaskChain.new(): types.TaskChain
	local self = setmetatable({
		_tasks = {},
		_janitor = types.janitor.new(),
		_status = "Pending",
		_isProcessing = false,
	}, TaskChain)

	self._promise = types.promise.resolve()
	self._janitor:Add(self._promise, "cancel")

	return self
end

--]
function TaskChain:call(func: (...any) -> ...any, ...): types.TaskChain
	table.insert(self._tasks, {
		type = "call",
		payload = { func = func, args = { ... } },
	})
	if not self._isProcessing then
		self._isProcessing = true
		self._status = "Running"
		_processNextTask(self)
	end
	return self
end

--]
function TaskChain:wait(duration: number?): types.TaskChain
	table.insert(self._tasks, {
		type = "wait",
		payload = { duration = (duration or 0.16666) },
	})
	if not self._isProcessing then
		self._isProcessing = true
		self._status = "Running"
		_processNextTask(self)
	end
	return self
end

--]
function TaskChain:promise(promise: types.Promise): types.TaskChain
	table.insert(self._tasks, {
		type = "promise",
		payload = { promise = promise },
	})
	if not self._isProcessing then
		self._isProcessing = true
		self._status = "Running"
		_processNextTask(self)
	end
	return self
end

--]
function TaskChain:andThen(onSuccess, onFailure): types.TaskChain
	table.insert(self._tasks, {
		type = "andThen",
		payload = { onSuccess = onSuccess, onFailure = onFailure },
	})
	if not self._isProcessing then
		self._isProcessing = true
		self._status = "Running"
		_processNextTask(self)
	end
	return self
end

--]
function TaskChain:track(item, cleanupMethod: string): types.TaskChain
	table.insert(self._tasks, {
		type = "track",
		payload = { item = item, cleanupMethod = cleanupMethod },
	})
	if not self._isProcessing then
		self._isProcessing = true
		self._status = "Running"
		_processNextTask(self)
	end
	return self
end

--]
function TaskChain:catch(errorHandler): types.TaskChain
	self._promise = self._promise:catch(errorHandler)
	self._promise:catch(function()
		if self._status ~= "Destroyed" then
			self._status = "Rejected"
		end
	end)
	return self
end

--]
function TaskChain:finally(handler): types.TaskChain
	self._promise = self._promise:finally(handler)
	self._promise:andThen(function()
		if self._status == "Running" then
			self._status = "Resolved"
		end
	end)
	return self
end

--]
function TaskChain:await(): any?
	local value = select(2, self._promise:await())
	self:destroy()
	return value
end

--]
function TaskChain:fork(): types.TaskChain
	local newChain = TaskChain.new()
	newChain._promise = self._promise
	return newChain
end

--]
function TaskChain:destroy()
	if self._status == "Destroyed" then
		return
	end

	self._status = "Destroyed"
	self._isProcessing = false
	self._tasks = {}

	self._janitor:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end

TaskChain.remove = TaskChain.destroy

return table.freeze(TaskChain)
