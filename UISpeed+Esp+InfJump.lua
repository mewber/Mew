local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer

local gameName = "Đang tải..."
local gameId = game.PlaceId

pcall(function()
    local info = MarketplaceService:GetProductInfo(gameId)
    gameName = info.Name
end)

local DEFAULT_WALKSPEED = 16
local MIN_SPEED = 16
local MAX_SPEED = 120
local BOOST_SPEED = 42 -- tốc độ mặc định khi boost

local espGui, espBtn
local espActive = false
local boostGui, boostBtn
local enforceConnection
local boostAktif = false
local infJumpActive = false
local statusText
local speedGui -- GUI chỉnh tốc độ
local speedValueLabel -- hiển thị số
local speedInput -- ô nhập số
local sliderBar, sliderKnob -- thanh trượt

local multiClickCount = 0
local firstClickAt = 0
local MULTI_CLICK_WINDOW = 1.2 -- 1.2 giây để bấm 4 lần

local function enableDragging(frame)
	local dragging, dragInput, dragStart, startPos
	local function update(input)
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then update(input) end
	end)
end

-- ===== Áp tốc độ =====
local function applySpeed(hum, spd)
	if hum then hum.WalkSpeed = spd end
end

local function startEnforceSpeed()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	if enforceConnection then enforceConnection:Disconnect() end

	enforceConnection = RunService.Heartbeat:Connect(function()
		if boostAktif and humanoid.WalkSpeed ~= BOOST_SPEED then
			humanoid.WalkSpeed = BOOST_SPEED
		end
	end)

	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if boostAktif and humanoid.WalkSpeed ~= BOOST_SPEED then
			humanoid.WalkSpeed = BOOST_SPEED
		end
	end)

	applySpeed(humanoid, BOOST_SPEED)
end

local function stopEnforceSpeed()
	if enforceConnection then enforceConnection:Disconnect() enforceConnection = nil end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then applySpeed(hum, DEFAULT_WALKSPEED) end
end

-- ===== GUI Chỉnh Tốc Độ =====
local function setBoostSpeedFromNumber(n)
	n = math.clamp(math.floor(tonumber(n) or BOOST_SPEED), MIN_SPEED, MAX_SPEED)
	BOOST_SPEED = n
	if speedValueLabel then speedValueLabel.Text = "Tốc độ: "..BOOST_SPEED end
	if speedInput then speedInput.Text = tostring(BOOST_SPEED) end
	-- cập nhật vị trí knob theo tốc độ
	if sliderBar and sliderKnob then
		local barAbs = sliderBar.AbsoluteSize.X
		if barAbs > 0 then
			local t = (BOOST_SPEED - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)
			local x = math.clamp(t * barAbs, 0, barAbs)
			sliderKnob.Position = UDim2.new(0, x - sliderKnob.AbsoluteSize.X/2, 0.5, 0)
		end
	end
	-- nếu đang boost, cập nhật ngay
	if boostAktif then
		local hum = (player.Character or player.CharacterAdded:Wait()):FindFirstChildOfClass("Humanoid")
		if hum then applySpeed(hum, BOOST_SPEED) end
	end
end

local function beginDragSlider(input)
	local connMove, connEnd
	local barAbsPos = sliderBar.AbsolutePosition
	local barAbsSize = sliderBar.AbsoluteSize
	local function update(pos)
		local x = math.clamp(pos.X - barAbsPos.X, 0, barAbsSize.X)
		local t = x / barAbsSize.X
		local value = MIN_SPEED + t * (MAX_SPEED - MIN_SPEED)
		setBoostSpeedFromNumber(math.floor(value + 0.5))
	end
	update(input.Position)
	connMove = UserInputService.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			update(inp.Position)
		end
	end)
	connEnd = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			if connMove then connMove:Disconnect() end
			if connEnd then connEnd:Disconnect() end
		end
	end)
end

local function createSpeedConfigGUI()
	if speedGui then return end
	speedGui = Instance.new("ScreenGui")
	speedGui.Name = "SpeedConfigGUI"
	speedGui.ResetOnSpawn = false
	speedGui.Enabled = false
	speedGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame", speedGui)
	frame.Size = UDim2.new(0, 280, 0, 150)
	frame.Position = UDim2.new(0.5, -140, 0.5, -75)
	frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner", frame)
	corner.CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(0,200,255)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.1

	enableDragging(frame)

	local title = Instance.new("TextLabel", frame)
	title.Size = UDim2.new(1, -40, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.TextColor3 = Color3.new(1,1,1)
	title.Text = "Chỉnh tốc độ Boost"

	local closeBtn = Instance.new("TextButton", frame)
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -30, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 16
	closeBtn.TextColor3 = Color3.new(1,1,1)
	closeBtn.Text = "X"
	closeBtn.AutoButtonColor = true
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)
	closeBtn.MouseButton1Click:Connect(function() speedGui.Enabled = false end)

	-- Thanh trượt
	sliderBar = Instance.new("Frame", frame)
	sliderBar.Size = UDim2.new(1, -40, 0, 6)
	sliderBar.Position = UDim2.new(0, 20, 0, 70)
	sliderBar.BackgroundColor3 = Color3.fromRGB(60,60,60)
	sliderBar.BorderSizePixel = 0
	Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(0,3)

	sliderKnob = Instance.new("Frame", sliderBar)
	sliderKnob.Size = UDim2.new(0, 16, 0, 16)
	sliderKnob.Position = UDim2.new(0, 0, 0.5, 0)
	sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	sliderKnob.BackgroundColor3 = Color3.fromRGB(0,200,255)
	sliderKnob.BorderSizePixel = 0
	Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1,0)

	sliderBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDragSlider(input)
		end
	end)

	-- Nhãn và ô nhập
	speedValueLabel = Instance.new("TextLabel", frame)
	speedValueLabel.Size = UDim2.new(0.6, -20, 0, 24)
	speedValueLabel.Position = UDim2.new(0, 20, 0, 100)
	speedValueLabel.BackgroundTransparency = 1
	speedValueLabel.Font = Enum.Font.FredokaOne
	speedValueLabel.TextSize = 16
	speedValueLabel.TextColor3 = Color3.new(1,1,1)
	speedValueLabel.TextXAlignment = Enum.TextXAlignment.Left

	speedInput = Instance.new("TextBox", frame)
	speedInput.Size = UDim2.new(0.4, -20, 0, 28)
	speedInput.Position = UDim2.new(0.6, 0, 0, 98)
	speedInput.BackgroundColor3 = Color3.fromRGB(40,40,40)
	speedInput.TextColor3 = Color3.new(1,1,1)
	speedInput.PlaceholderText = tostring(BOOST_SPEED)
	speedInput.Text = tostring(BOOST_SPEED)
	speedInput.Font = Enum.Font.FredokaOne
	speedInput.TextSize = 16
	speedInput.ClearTextOnFocus = false
	Instance.new("UICorner", speedInput).CornerRadius = UDim.new(0,6)

	speedInput.FocusLost:Connect(function(enterPressed)
		setBoostSpeedFromNumber(speedInput.Text)
	end)

	-- min/max
	local minLbl = Instance.new("TextLabel", frame)
	minLbl.Size = UDim2.new(0, 60, 0, 18)
	minLbl.Position = UDim2.new(0, 20, 0, 52)
	minLbl.BackgroundTransparency = 1
	minLbl.Text = "Min: "..MIN_SPEED
	minLbl.Font = Enum.Font.FredokaOne
	minLbl.TextSize = 12
	minLbl.TextColor3 = Color3.fromRGB(180,180,180)
	minLbl.TextXAlignment = Enum.TextXAlignment.Left

	local maxLbl = Instance.new("TextLabel", frame)
	maxLbl.Size = UDim2.new(0, 80, 0, 18)
	maxLbl.Position = UDim2.new(1, -100, 0, 52)
	maxLbl.BackgroundTransparency = 1
	maxLbl.Text = "Max: "..MAX_SPEED
	maxLbl.Font = Enum.Font.FredokaOne
	maxLbl.TextSize = 12
	maxLbl.TextColor3 = Color3.fromRGB(180,180,180)
	maxLbl.TextXAlignment = Enum.TextXAlignment.Right

	setBoostSpeedFromNumber(BOOST_SPEED)
end

local function toggleSpeedGUI()
	if not speedGui then createSpeedConfigGUI() end
	speedGui.Enabled = not speedGui.Enabled
end

-- ===== Boost GUI & Trạng thái =====
local function buatBoostGUI()
	if boostGui then return end

	boostGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
	boostGui.Name = "BoostGUI"
	boostGui.ResetOnSpawn = false

	boostBtn = Instance.new("TextButton", boostGui)
	boostBtn.Size = UDim2.new(0, 96, 0, 32)
	boostBtn.Position = UDim2.new(0.5, 0, 1, -70)
	boostBtn.AnchorPoint = Vector2.new(0.5, 1)
	boostBtn.BackgroundColor3 = Color3.fromRGB(0, 85, 170)
	boostBtn.TextColor3 = Color3.new(1, 1, 1)
	boostBtn.TextStrokeColor3 = Color3.new(0, 0, 0)
	boostBtn.TextStrokeTransparency = 0
	boostBtn.Font = Enum.Font.FredokaOne
	boostBtn.TextSize = 17
	boostBtn.BorderSizePixel = 0
	boostBtn.AutoButtonColor = false
	boostBtn.Text = "Boost OFF"

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = boostBtn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 200, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = boostBtn

	local clickSound = Instance.new("Sound")
	clickSound.SoundId = "rbxassetid://9080070218"
	clickSound.Volume = 1
	clickSound.Parent = boostBtn

	enableDragging(boostBtn)

	local statusFrame = Instance.new("Frame", boostGui)
	statusFrame.Size = UDim2.new(0, 260, 0, 138)
	statusFrame.Position = UDim2.new(1, -250, 0, 10)
	statusFrame.AnchorPoint = Vector2.new(0, 0)
	statusFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	statusFrame.BackgroundTransparency = 0.2
	statusFrame.BorderSizePixel = 0

	local bgImage = Instance.new("ImageLabel")
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.Position = UDim2.new(0, 0, 0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://18878365966"
	bgImage.ZIndex = 0
	bgImage.Parent = statusFrame

	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 6)
	corner2.Parent = statusFrame

	local stroke2 = Instance.new("UIStroke")
	stroke2.Color = Color3.fromRGB(0, 200, 255)
	stroke2.Thickness = 1.5
	stroke2.Transparency = 0.1
	stroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke2.Parent = statusFrame

	statusText = Instance.new("TextLabel", statusFrame)
	statusText.Size = UDim2.new(1, -10, 1, -10)
	statusText.Position = UDim2.new(0, 5, 0, 5)
	statusText.BackgroundTransparency = 1
	statusText.TextColor3 = Color3.new(1, 1, 1)
	statusText.TextStrokeColor3 = Color3.new(0, 0, 0)
	statusText.TextStrokeTransparency = 0
	statusText.Font = Enum.Font.FredokaOne
	statusText.TextSize = 14
	statusText.TextXAlignment = Enum.TextXAlignment.Left
	statusText.TextYAlignment = Enum.TextYAlignment.Top
	statusText.RichText = true
	statusText.ZIndex = 1
	statusText.Text = "..."

	-- Credit “Tạo bởi Kha Hub” góc phải dưới
	local credit = Instance.new("TextLabel", statusFrame)
	credit.Size = UDim2.new(0, 140, 0, 18)
	credit.AnchorPoint = Vector2.new(1,1)
	credit.Position = UDim2.new(1, -6, 1, -6)
	credit.BackgroundTransparency = 1
	credit.Text = "Mew Hub"
	credit.Font = Enum.Font.FredokaOne
	credit.TextSize = 12
	credit.TextColor3 = Color3.fromRGB(160,160,160)
	credit.TextXAlignment = Enum.TextXAlignment.Right
	credit.ZIndex = 2

	enableDragging(statusFrame)

	-- Click nút Boost
	boostBtn.MouseButton1Click:Connect(function()
		clickSound:Play()

		-- hiệu ứng
		local tweenUp = TweenService:Create(boostBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 106, 0, 38) })
		local tweenDown = TweenService:Create(boostBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 96, 0, 32) })
		tweenUp:Play(); tweenUp.Completed:Connect(function() tweenDown:Play() end)

		-- toggle boost
		boostAktif = not boostAktif
		if boostAktif then
			boostBtn.Text = "Boost ON"
			startEnforceSpeed()
		else
			boostBtn.Text = "Boost OFF"
			stopEnforceSpeed()
			boostTime = 0
		end

		-- đếm 5 lần nhanh để mở GUI speed
		local now = os.clock()
		if now - firstClickAt > MULTI_CLICK_WINDOW then
			firstClickAt = now
			multiClickCount = 1
		else
			multiClickCount += 1
		end
		if multiClickCount >= 4 then
			multiClickCount = 0
			firstClickAt = 0
			toggleSpeedGUI()
		end
	end)
end

-- ===== Inf Jump GUI =====
local function createInfJumpGUI()
	local infJumpGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
	infJumpGui.Name = "InfJumpGUI"
	infJumpGui.ResetOnSpawn = false

	local infJumpBtn = Instance.new("TextButton", infJumpGui)
	infJumpBtn.Size = UDim2.new(0, 120, 0, 40)
	infJumpBtn.Position = UDim2.new(0.5, -150, 1, -70)
	infJumpBtn.AnchorPoint = Vector2.new(0.5, 1)
	infJumpBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
	infJumpBtn.TextColor3 = Color3.new(1, 1, 1)
	infJumpBtn.TextStrokeColor3 = Color3.new(0, 0, 0)
	infJumpBtn.TextStrokeTransparency = 0
	infJumpBtn.Font = Enum.Font.FredokaOne
	infJumpBtn.TextSize = 18
	infJumpBtn.BorderSizePixel = 0
	infJumpBtn.AutoButtonColor = false
	infJumpBtn.Text = "Inf Jump OFF"

	Instance.new("UICorner", infJumpBtn).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", infJumpBtn)
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local clickSound = Instance.new("Sound", infJumpBtn)
	clickSound.SoundId = "rbxassetid://9080070218"
	clickSound.Volume = 1

	enableDragging(infJumpBtn)

	UserInputService.JumpRequest:Connect(function()
		if infJumpActive then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end
	end)

	infJumpBtn.MouseButton1Click:Connect(function()
		clickSound:Play()
		infJumpActive = not infJumpActive
		local tweenUp = TweenService:Create(infJumpBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 130, 0, 46) })
		local tweenDown = TweenService:Create(infJumpBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 120, 0, 40) })
		tweenUp:Play(); tweenUp.Completed:Connect(function() tweenDown:Play() end)
		infJumpBtn.Text = infJumpActive and "Inf Jump ON" or "Inf Jump OFF"
	end)
end

local espConnections = {}

local function clearESP()
    for _, v in ipairs(Players:GetPlayers()) do
        if v.Character then
            local head = v.Character:FindFirstChild("Head")
            if head and head:FindFirstChild("KhaESPText") then
                head.KhaESPText:Destroy()
            end
        end
    end
    for _, v in ipairs(espConnections) do
        if v.conn then v.conn:Disconnect() end
    end
    table.clear(espConnections)
end

local function createESP(plr)
    if plr == player or not plr.Character then return end
    local char = plr.Character
    local head = char:FindFirstChild("Head")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not head or not humanoid then return end

    -- Text hiển thị tên & máu
    local bill = Instance.new("BillboardGui")
    bill.Name = "KhaESPText"
    bill.Size = UDim2.new(0, 250, 0, 30)
    bill.Adornee = head
    bill.AlwaysOnTop = true
    bill.Parent = head

    local nameLabel = Instance.new("TextLabel", bill)
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Font = Enum.Font.FredokaOne
    nameLabel.TextSize = 14

    local conn = RunService.Heartbeat:Connect(function()
        if humanoid and humanoid.Parent then
            local health = math.floor(humanoid.Health)
            local maxHealth = math.floor(humanoid.MaxHealth)
            nameLabel.Text = string.format("ชื่อ : %s | เลือด : %d/%d", plr.Name, health, maxHealth)
        end
    end)

    table.insert(espConnections, {conn = conn})
end

local function updateAllESP()
    clearESP()
    if not espActive then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            createESP(plr)
        end
    end
end

-- Luôn theo dõi người mới vào/respawn
Players.PlayerAdded:Connect(function(plr)
    if espActive then
        plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            createESP(plr)
        end)
    end
end)

Players.PlayerRemoving:Connect(function()
    updateAllESP()
end)

-- ===== Tạo ESP GUI =====
local function createESPGUI()
    local pg = player:WaitForChild("PlayerGui")
    local espGui = Instance.new("ScreenGui", pg)
    espGui.Name = "EspGUI"
    espGui.ResetOnSpawn = false

    local espBtn = Instance.new("TextButton", espGui)
    espBtn.Size = UDim2.new(0, 96, 0, 32)
    espBtn.Position = UDim2.new(0.5, 0, 1, -120)
    espBtn.AnchorPoint = Vector2.new(0.5, 1)
    espBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    espBtn.TextColor3 = Color3.new(1, 1, 1)
    espBtn.TextStrokeColor3 = Color3.new(0, 0, 0)
    espBtn.TextStrokeTransparency = 0
    espBtn.Font = Enum.Font.FredokaOne
    espBtn.TextSize = 17
    espBtn.BorderSizePixel = 0
    espBtn.AutoButtonColor = false
    espBtn.Text = "ESP OFF"

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = espBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 0)
    stroke.Thickness = 2
    stroke.Transparency = 0.1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = espBtn

    local clickSound = Instance.new("Sound")
    clickSound.SoundId = "rbxassetid://9080070218"
    clickSound.Volume = 1
    clickSound.Parent = espBtn

    enableDragging(espBtn)

    espBtn.MouseButton1Click:Connect(function()
        clickSound:Play()
        espActive = not espActive

        if espActive then
            espBtn.Text = "ESP ON"
            updateAllESP()
        else
            espBtn.Text = "ESP OFF"
            clearESP()
        end
    end)
end

-- ===== Màu chữ trạng thái ESP giống boost/inf jump =====
local function getESPColor()
    return espActive and '<font color="rgb(0,255,0)">ON</font>' or '<font color="rgb(255,0,0)">OFF</font>'
end

-- ===== Cập nhật trạng thái mỗi frame =====
local fps, lastTime, counter = 0, tick(), 0
RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not statusText or not hum then return end

	local ws = math.floor(hum.WalkSpeed + 0.5)
	local jp = math.floor(hum.JumpPower + 0.5)
	local boostColor = boostAktif and "<font color='rgb(0,255,0)'>ON</font>" or "<font color='rgb(255,0,0)'>OFF</font>"
	local infJumpColor = infJumpActive and "<font color='rgb(0,255,0)'>ON</font>" or "<font color='rgb(255,0,0)'>OFF</font>"
	local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())

	statusText.Text =
    "ชื่อเกม: " .. gameName .. " (" .. gameId .. ")" ..
    "\nความเร็วในการทำงานปัจจุบัน: " .. ws ..
    "\nกำลังกระโดดปัจจุบัน: " .. jp ..
    "\nเพิ่มสถานะ: " .. boostColor ..
    "\nชุดเพิ่มความเร็ว: " .. BOOST_SPEED ..
    "\nกระโดดไม่จำกัด: " .. infJumpColor ..
    "\nมองคน: " .. getESPColor() ..
    "\nปิง: " .. ping .. " ms" ..
    "\nเฟมเลส: " .. fps

	counter += 1
	if tick() - lastTime >= 1 then
		fps = counter
		counter = 0
		lastTime = tick()
	end
end)

-- ===== Khởi tạo =====
buatBoostGUI()
createInfJumpGUI()
createESPGUI()
createSpeedConfigGUI() -- tạo sẵn (ẩn), mở bằng 5 lần click nhanh

-- ===== Thông báo cảm ơn (giữ nguyên của bạn) =====
local CoreGui = game:GetService("CoreGui")

if CoreGui:FindFirstChild("ThongBaoCamOn") then
	CoreGui.ThongBaoCamOn:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ThongBaoCamOn"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CoreGui

local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://17582299860"
sound.Volume = 1
sound.PlayOnRemove = true
sound.Parent = gui
sound:Destroy()

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(1, 1)
frame.Position = UDim2.new(1, -10, 1, -10)
frame.Size = UDim2.new(0, 250, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.BackgroundTransparency = 1
frame.Parent = gui

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 255, 0)
uiStroke.Thickness = 2
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
uiStroke.Transparency = 1
uiStroke.Parent = frame

local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0, 8)
uicorner.Parent = frame

local title = Instance.new("TextLabel")
title.Text = "🔔 การแจ้งเตือน"
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.new(0, 10, 0, 5)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextTransparency = 1
title.Parent = frame

local content = Instance.new("TextLabel")
content.Text = "ขอขอบคุณที่ใช้สคริปต์!"
content.Font = Enum.Font.Gotham
content.TextSize = 8
content.TextColor3 = Color3.fromRGB(200, 255, 200)
content.BackgroundTransparency = 1
content.Size = UDim2.new(1, -20, 0, 40)
content.Position = UDim2.new(0, 10, 0, 40)
content.TextXAlignment = Enum.TextXAlignment.Left
content.TextTransparency = 1
content.Parent = frame

TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.2}):Play()
TweenService:Create(uiStroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
TweenService:Create(title, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
TweenService:Create(content, TweenInfo.new(0.3), {TextTransparency = 0}):Play()

task.delay(2, function()
	TweenService:Create(title, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
	TweenService:Create(content, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
	task.delay(0.3, function()
		TweenService:Create(frame, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
		TweenService:Create(uiStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()
		task.delay(0.2, function() gui:Destroy() end)
	end)
end)

-- Reset boost khi nhân vật chết
Players.LocalPlayer.CharacterAdded:Connect(function()
	if boostAktif then startEnforceSpeed() else stopEnforceSpeed() end
end)

-- ===== HIỆU ỨNG ẨN/HIỆN + ÂM THANH MASTER TOGGLE =====
local TARGET_GUIS = { "BoostGUI", "InfJumpGUI", "EspGUI" } -- KHÔNG đụng SpeedConfigGUI

local function recordOriginalTransparency(obj)
	-- Lưu 1 lần các giá trị gốc
	if obj:IsA("Frame") or obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		if obj:GetAttribute("Orig_BG") == nil and obj.BackgroundTransparency ~= nil then
			obj:SetAttribute("Orig_BG", obj.BackgroundTransparency)
		end
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		if obj:GetAttribute("Orig_T") == nil then obj:SetAttribute("Orig_T", obj.TextTransparency or 0) end
		if obj:GetAttribute("Orig_TS") == nil then obj:SetAttribute("Orig_TS", obj.TextStrokeTransparency or 0) end
	end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		if obj:GetAttribute("Orig_I") == nil then obj:SetAttribute("Orig_I", obj.ImageTransparency or 0) end
	end
	if obj:IsA("UIStroke") then
		if obj:GetAttribute("Orig_S") == nil then obj:SetAttribute("Orig_S", obj.Transparency or 0) end
	end
end

local function setInvisibleInstant(obj)
	if obj:IsA("Frame") or obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		if obj.BackgroundTransparency ~= nil then obj.BackgroundTransparency = 1 end
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		obj.TextTransparency = 1
		obj.TextStrokeTransparency = 1
	end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		obj.ImageTransparency = 1
	end
	if obj:IsA("UIStroke") then
		obj.Transparency = 1
	end
end

local function tweenToOriginal(obj, duration)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {}
	if obj:GetAttribute("Orig_BG") ~= nil then goal.BackgroundTransparency = obj:GetAttribute("Orig_BG") end
	if obj:GetAttribute("Orig_T")  ~= nil then goal.TextTransparency       = obj:GetAttribute("Orig_T")  end
	if obj:GetAttribute("Orig_TS") ~= nil then goal.TextStrokeTransparency = obj:GetAttribute("Orig_TS") end
	if obj:GetAttribute("Orig_I")  ~= nil then goal.ImageTransparency      = obj:GetAttribute("Orig_I")  end
	if obj:GetAttribute("Orig_S")  ~= nil then goal.Transparency           = obj:GetAttribute("Orig_S")  end
	if next(goal) then TweenService:Create(obj, info, goal):Play() end
end

local function tweenToInvisible(obj, duration)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local goal = {}
	if obj:IsA("Frame") or obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		if obj.BackgroundTransparency ~= nil then goal.BackgroundTransparency = 1 end
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		goal.TextTransparency = 1; goal.TextStrokeTransparency = 1
	end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		goal.ImageTransparency = 1
	end
	if obj:IsA("UIStroke") then
		goal.Transparency = 1
	end
	if next(goal) then TweenService:Create(obj, info, goal):Play() end
end

local function fadeGui(gui, show, duration)
	-- Lưu gốc
	for _, d in ipairs(gui:GetDescendants()) do recordOriginalTransparency(d) end
	recordOriginalTransparency(gui)

	if show then
		gui.Enabled = true
		for _, d in ipairs(gui:GetDescendants()) do setInvisibleInstant(d) end
		setInvisibleInstant(gui)
		for _, d in ipairs(gui:GetDescendants()) do tweenToOriginal(d, duration) end
		tweenToOriginal(gui, duration)
	else
		for _, d in ipairs(gui:GetDescendants()) do tweenToInvisible(d, duration) end
		tweenToInvisible(gui, duration)
		task.delay(duration, function() gui.Enabled = false end)
	end
end

local function animateAllGui(on)
	local pg = player:WaitForChild("PlayerGui")
	for _, n in ipairs(TARGET_GUIS) do
		local g = pg:FindFirstChild(n)
		if g then fadeGui(g, on, 0.25) end
	end
end

-- ===== MASTER TOGGLE (bầu dục bên trái, kéo được, có âm thanh) =====
local function createMasterToggleGUI()
	local pg = player:WaitForChild("PlayerGui")
	local toggleGui = Instance.new("ScreenGui")
	toggleGui.Name = "MasterToggleGUI"
	toggleGui.ResetOnSpawn = false
	toggleGui.Parent = pg

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 140, 0, 40)
	frame.Position = UDim2.new(0, 10, 0, 10)
	frame.BackgroundColor3 = Color3.fromRGB(0, 85, 170)
	frame.BorderSizePixel = 0
	frame.Parent = toggleGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(0, 200, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.1

	-- Âm thanh
	local sndClick = Instance.new("Sound", frame)
	sndClick.SoundId = "rbxassetid://9080070218" -- click
	sndClick.Volume = 1
	local sndWhoosh = Instance.new("Sound", frame)
	sndWhoosh.SoundId = "rbxassetid://9080070218" -- dùng tạm, khác pitch
	sndWhoosh.Volume = 1
	sndWhoosh.PlaybackSpeed = 0.85

	enableDragging(frame)

	local btn = Instance.new("TextButton", frame)
	btn.Size = UDim2.new(1, -8, 1, -8)
	btn.Position = UDim2.new(0, 4, 0, 4)
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 18
	btn.TextColor3 = Color3.new(1,1,1)
	btn.TextStrokeColor3 = Color3.new(0,0,0)
	btn.TextStrokeTransparency = 0

	local showAll = true
	local function refreshVisual()
		btn.Text = showAll and "GUI ON" or "GUI OFF"
		frame.BackgroundColor3 = showAll and Color3.fromRGB(0,85,170) or Color3.fromRGB(60,60,60)
		stroke.Color = showAll and Color3.fromRGB(0,200,255) or Color3.fromRGB(160,160,160)
	end
	refreshVisual()

	btn.MouseButton1Click:Connect(function()
		sndClick:Play()
		-- nhún
		local up = TweenService:Create(frame, TweenInfo.new(0.08), { Size = UDim2.new(0, 100, 0, 46) })
		local down = TweenService:Create(frame, TweenInfo.new(0.08), { Size = UDim2.new(0, 150, 0, 40) })
		up:Play(); up.Completed:Connect(function() down:Play() end)

		showAll = not showAll
		if not showAll then sndWhoosh:Play() end -- khi ẩn tất cả, phát whoosh
		animateAllGui(showAll)
		refreshVisual()
	end)
end

-- Lần đầu: bật và hiện mượt
for _, n in ipairs(TARGET_GUIS) do
	local g = player:WaitForChild("PlayerGui"):FindFirstChild(n)
	if g then fadeGui(g, true, 0.15) end
end
createMasterToggleGUI()