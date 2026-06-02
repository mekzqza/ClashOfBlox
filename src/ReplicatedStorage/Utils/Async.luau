--!strict
--[[
╔════════════════════════════════════════════════════════════════╗
║                      ASYNC UTILITIES                           ║
╠════════════════════════════════════════════════════════════════╣
║ Utility functions for async operations                         ║
║ countdown, debounce, throttle, retry, timeout, once, etc.      ║
╚════════════════════════════════════════════════════════════════╝
]]

local Async = {}

--------------------------------------------------------------------------------
-- 📦 TYPES
--------------------------------------------------------------------------------

export type CancelFunction = () -> ()

--------------------------------------------------------------------------------
-- ⏱️ COUNTDOWN
--------------------------------------------------------------------------------

--[[
    นับถอยหลังและเรียก callback ทุกวินาที

    USAGE:
    ```lua
    Async.countdown(5,
        function(timeLeft)
            print(`เหลือ {timeLeft} วินาที`)
        end,
        function()
            print("หมดเวลา!")
        end
    )
    ```

    OUTPUT:
    เหลือ 5 วินาที
    เหลือ 4 วินาที
    เหลือ 3 วินาที
    เหลือ 2 วินาที
    เหลือ 1 วินาที
    หมดเวลา!
]]
function Async.countdown(seconds: number, onTick: (timeLeft: number) -> (), onDone: () -> ())
	task.spawn(function()
		for i = seconds, 1, -1 do
			onTick(i)
			task.wait(1)
		end
		onDone()
	end)
end

function Async.doAfter(seconds: number, onDone: () -> ())
	task.spawn(function()
		for i = seconds, 1, -1 do
			task.wait(1)
		end
		onDone()
	end)
end
--------------------------------------------------------------------------------
-- ⏱️ CANCELABLE COUNTDOWN
--------------------------------------------------------------------------------

--[[
    เหมือน countdown แต่ยกเลิกได้

    USAGE:
    ```lua
    local cancel = Async.cancelableCountdown(30,
        function(timeLeft)
            CountdownLabel.Text = tostring(timeLeft)
        end,
        function()
            print("Done!")
        end
    )

    -- ยกเลิกเมื่อไหร่ก็ได้
    someButton.Activated:Connect(function()
        cancel()
    end)
    ```
]]
function Async.cancelableCountdown(seconds: number, onTick: (timeLeft: number) -> (), onDone: () -> ()): CancelFunction
	local cancelled = false

	task.spawn(function()
		for i = seconds, 1, -1 do
			if cancelled then
				return
			end
			onTick(i)
			task.wait(1)
		end
		if not cancelled then
			onDone()
		end
	end)

	return function()
		cancelled = true
	end
end

--------------------------------------------------------------------------------
-- 🚫 DEBOUNCE
--------------------------------------------------------------------------------

--[[
    ป้องกันการเรียก function ถี่เกินไป
    จะทำงานแค่ครั้งแรก แล้วรอ cooldown

    USAGE:
    ```lua
    local onAttack = Async.debounce(0.5, function(player)
        print(`{player.Name} attacked!`)
    end)

    -- กดถี่แค่ไหนก็ทำแค่ 1 ครั้ง / 0.5 วินาที
    AttackButton.Activated:Connect(function()
        onAttack(player)
    end)
    ```

    TIMELINE:
    0.0s: กด → ทำงาน ✅
    0.1s: กด → ไม่ทำ ❌ (cooldown)
    0.2s: กด → ไม่ทำ ❌ (cooldown)
    0.5s: กด → ทำงาน ✅
]]
function Async.debounce<T...>(seconds: number, fn: (T...) -> ()): (T...) -> ()
	local lastCall = 0

	return function(...: T...)
		local now = os.clock()
		if now - lastCall >= seconds then
			lastCall = now
			fn(...)
		end
	end
end

--------------------------------------------------------------------------------
-- 🚦 THROTTLE
--------------------------------------------------------------------------------

--[[
    จำกัดความถี่ของ function
    ต่างจาก debounce: throttle จะ block จนกว่า function จะเสร็จ

    USAGE:
    ```lua
    local onScroll = Async.throttle(0.1, function()
        updateScrollPosition()
    end)

    ScrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        onScroll()
    end)
    ```

    TIMELINE:
    0.0s: เรียก → ทำงาน ✅ (waiting = true)
    0.05s: เรียก → ไม่ทำ ❌ (waiting)
    0.1s: waiting = false
    0.1s: เรียก → ทำงาน ✅
]]
function Async.throttle<T...>(seconds: number, fn: (T...) -> ()): (T...) -> ()
	local waiting = false

	return function(...: T...)
		if waiting then
			return
		end
		waiting = true
		fn(...)
		task.delay(seconds, function()
			waiting = false
		end)
	end
end

--------------------------------------------------------------------------------
-- 🔄 RETRY
--------------------------------------------------------------------------------

--[[
    ลองทำ function ซ้ำถ้า fail

    USAGE:
    ```lua
    Async.retry(3, 1,
        function()
            local success = DataStoreService:SetAsync(key, data)
            return success
        end,
        function()
            warn("Failed to save after 3 attempts!")
        end
    )
    ```

    PARAMETERS:
    - times: จำนวนครั้งที่จะลอง
    - delay: รอกี่วินาทีระหว่างแต่ละครั้ง
    - fn: function ที่ต้อง return true ถ้าสำเร็จ
    - onFail: เรียกเมื่อ fail ทุกครั้ง
]]
function Async.retry(times: number, delay: number, fn: () -> boolean, onFail: () -> ())
	task.spawn(function()
		for _ = 1, times do
			local success = fn()
			if success then
				return
			end
			task.wait(delay)
		end
		onFail()
	end)
end

--------------------------------------------------------------------------------
-- ⏰ TIMEOUT
--------------------------------------------------------------------------------

--[[
    ทำ function แต่ยกเลิกถ้านานเกิน

    USAGE:
    ```lua
    Async.timeout(5,
        function()
            local data = fetchDataFromServer()
            processData(data)
        end,
        function()
            warn("Request timed out!")
            showErrorUI()
        end
    )
    ```

    NOTE: ไม่ได้หยุด function จริงๆ แค่เรียก onTimeout
          ถ้าต้องการหยุดจริง ใช้ cancelableTimeout
]]
function Async.timeout(seconds: number, fn: () -> (), onTimeout: () -> ())
	local done = false

	task.spawn(function()
		fn()
		done = true
	end)

	task.delay(seconds, function()
		if not done then
			onTimeout()
		end
	end)
end

--------------------------------------------------------------------------------
-- 1️⃣ ONCE
--------------------------------------------------------------------------------

--[[
    ทำ function แค่ครั้งเดียว ครั้งต่อไปจะไม่ทำ

    USAGE:
    ```lua
    local initPlayer = Async.once(function(player)
        print(`{player.Name} initialized!`)
        setupInventory(player)
        loadData(player)
    end)

    -- เรียกกี่ครั้งก็ทำแค่ครั้งแรก
    initPlayer(player) -- "Player1 initialized!" ✅
    initPlayer(player) -- ไม่ทำอะไร ❌
    initPlayer(player) -- ไม่ทำอะไร ❌
    ```
]]
function Async.once<T...>(fn: (T...) -> ()): (T...) -> ()
	local called = false

	return function(...: T...)
		if called then
			return
		end
		called = true
		fn(...)
	end
end

--------------------------------------------------------------------------------
-- ⏳ DELAY WITH CANCEL
--------------------------------------------------------------------------------

--[[
    เหมือน task.delay แต่ยกเลิกได้

    USAGE:
    ```lua
    local cancel = Async.delayWithCancel(5, function()
        print("5 seconds passed!")
    end)

    -- ยกเลิกก่อน 5 วินาที
    task.wait(2)
    cancel() -- จะไม่ print อะไร
    ```
]]
function Async.delayWithCancel(seconds: number, fn: () -> ()): CancelFunction
	local cancelled = false

	task.delay(seconds, function()
		if not cancelled then
			fn()
		end
	end)

	return function()
		cancelled = true
	end
end

--------------------------------------------------------------------------------
-- 🔁 INTERVAL
--------------------------------------------------------------------------------

--[[
    ทำ function ซ้ำๆ ทุก X วินาที (ยกเลิกได้)

    USAGE:
    ```lua
    local stop = Async.interval(1, function()
        print("Tick!")
        updateTimer()
    end)

    -- หยุดหลังจาก 10 วินาที
    task.delay(10, function()
        stop()
    end)
    ```
]]
function Async.interval(seconds: number, fn: () -> ()): CancelFunction
	local running = true

	task.spawn(function()
		while running do
			fn()
			task.wait(seconds)
		end
	end)

	return function()
		running = false
	end
end

--------------------------------------------------------------------------------
-- ⏳ WAIT UNTIL
--------------------------------------------------------------------------------

--[[
    รอจนกว่า condition จะเป็น true

    USAGE:
    ```lua
    Async.waitUntil(
        function()
            return player.Character ~= nil
        end,
        function()
            print("Character loaded!")
            setupCharacter(player.Character)
        end,
        10 -- timeout (optional)
    )
    ```
]]
function Async.waitUntil(condition: () -> boolean, onReady: () -> (), timeout: number?)
	local maxTime = timeout or 30
	local elapsed = 0

	task.spawn(function()
		while not condition() do
			task.wait(0.1)
			elapsed += 0.1
			if elapsed >= maxTime then
				warn("[Async.waitUntil] Timeout!")
				return
			end
		end
		onReady()
	end)
end

--------------------------------------------------------------------------------
-- 🔗 CHAIN
--------------------------------------------------------------------------------

--[[
    ทำหลาย function ต่อกันตามลำดับ

    USAGE:
    ```lua
    Async.chain({
        function(next)
            print("Step 1")
            task.wait(1)
            next()
        end,
        function(next)
            print("Step 2")
            task.wait(1)
            next()
        end,
        function(next)
            print("Step 3 - Done!")
        end,
    })
    ```

    OUTPUT:
    Step 1
    (wait 1s)
    Step 2
    (wait 1s)
    Step 3 - Done!
]]
function Async.chain(steps: { (next: () -> ()) -> () })
	local index = 1

	local function runNext()
		if index > #steps then
			return
		end

		local step = steps[index]
		index += 1
		step(runNext)
	end

	task.spawn(runNext)
end

return Async
