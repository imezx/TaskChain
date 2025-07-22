--!strict
--!optimize 2
local promise = require(script.Parent.Parent.promise)
local janitor = require(script.Parent.Parent.janitor)

export type Promise<T...> = promise.TypedPromise<T...>
export type Janitor = janitor.Janitor

export type task = {
	type: "call" | "wait" | "promise" | "andThen" | "catch" | "finally" | "track",
	payload: any,
}

export type status = "Pending" | "Running" | "Resolved" | "Rejected" | "Destroyed"

export type TaskChain = {
	call: (self: TaskChain, func: (...any) -> ...any, ...any) -> TaskChain,
	wait: (self: TaskChain, duration: number) -> TaskChain,

	promise: (self: TaskChain, promise: Promise) -> TaskChain,
	andThen: (self: TaskChain, onSuccess: ((...any) -> ...any)?, onFailure: ((any) -> any)?) -> TaskChain,
	track: <T>(self: TaskChain, item: T, cleanupMethod: string | boolean | nil) -> TaskChain,

	catch: (self: TaskChain, errorHandler: (err: any) -> any) -> TaskChain,
	finally: (self: TaskChain, handler: () -> ()) -> TaskChain,
	destroy: (self: TaskChain) -> (),

	await: (self: TaskChain) -> any?,
	fork: (self: TaskChain) -> TaskChain,

	_tasks: { task },
	_janitor: Janitor,
	_promise: Promise,
	_status: status,
	_isProcessing: boolean,
}

return {
	promise = promise,
	janitor = janitor,
}
