--!strict
-- Fenêtre « X te défie » avec compte à rebours, boutons Accepter / Refuser.
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Root = require(script.Parent.Root)

local C = Theme.Colors

local ChallengeDialog = {}

function ChallengeDialog.show(data: { [string]: any }, respond: (accept: boolean) -> ())
	local card = Kit.panel(Root.gui("Overlay"), {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 420, 0.42, 0),
		Size = UDim2.fromOffset(380, 170),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.04,
	})
	Root.scale(card)
	Kit.padding(card, 16)
	Kit.tween(card, 0.4, { Position = UDim2.new(1, -20, 0.42, 0) }, Enum.EasingStyle.Back)
	Kit.sound("Open", 0.4)
	Kit.new("ImageLabel", {
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.Night,
		Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60", tonumber(data.FromUserId) or 0),
		Parent = card,
	})
	Kit.label(card, "DÉFI EN DUEL", { Position = UDim2.fromOffset(68, 2), FontFace = Theme.Fonts.Title, TextSize = 12, TextColor3 = C.Gold })
	Kit.label(card, tostring(data.FromName or "?") .. " te défie (BO3) !", {
		Position = UDim2.fromOffset(68, 22),
		Size = UDim2.new(1, -68, 0, 36),
		FontFace = Theme.Fonts.Bold,
		TextSize = 16,
	})
	local bar = Kit.bar(card, C.Gold, { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 6) })
	local done = false
	local function finish(accept: boolean)
		if done then
			return
		end
		done = true
		respond(accept)
		Kit.tween(card, 0.3, { Position = UDim2.new(1, 420, 0.42, 0) })
		task.delay(0.3, function()
			card:Destroy()
		end)
	end
	Kit.button(card, "ACCEPTER", { Primary = true, Accent = C.Success, Size = UDim2.new(0.5, -6, 0, 42), Position = UDim2.new(0, 0, 1, -42) }, function()
		finish(true)
	end)
	Kit.button(card, "REFUSER", { Accent = C.Danger, Size = UDim2.new(0.5, -6, 0, 42), Position = UDim2.new(0.5, 6, 1, -42) }, function()
		finish(false)
	end)
	local expires = tonumber(data.Expires) or (Workspace:GetServerTimeNow() + 20)
	local total = math.max(expires - Workspace:GetServerTimeNow(), 1)
	task.spawn(function()
		while not done and card.Parent do
			local left = expires - Workspace:GetServerTimeNow()
			bar.set(left / total)
			if left <= 0 then
				done = true
				Kit.tween(card, 0.3, { Position = UDim2.new(1, 420, 0.42, 0) })
				task.wait(0.3)
				card:Destroy()
				return
			end
			task.wait(0.1)
		end
	end)
end

return ChallengeDialog
