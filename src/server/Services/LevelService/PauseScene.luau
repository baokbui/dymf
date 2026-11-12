--!strict
-- Snapshot animation speeds and the player's root; never replace a held attack pose with speed 1.
local CollectionService = game:GetService("CollectionService")
local Tags = require(game:GetService("ReplicatedStorage").Shared.Constants).TAGS
local Scene = {}
type Snapshot = { tracks: { [AnimationTrack]: number }, signals: { RBXScriptConnection }, root: BasePart?, anchored: boolean? }
local snapshots: { [Player]: Snapshot } = {}

local function units(player: Player): { Model }
	local result = {}
	for _, tag in { Tags.Brainrot, Tags.Monster } do
		for _, model in CollectionService:GetTagged(tag) do
			if model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then table.insert(result, model) end
		end
	end
	return result
end

function Scene.pause(player: Player)
	local snapshot: Snapshot = { tracks = {}, signals = {} }
	snapshots[player] = snapshot
	local function freezeCharacter(character: Model)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then snapshot.root, snapshot.anchored = root, root.Anchored; root.Anchored = true end
	end
	if player.Character then freezeCharacter(player.Character) end
	table.insert(snapshot.signals, player.CharacterAdded:Connect(freezeCharacter))
	for _, model in units(player) do
		model:SetAttribute("DayPaused", true)
		local animator = model:FindFirstChildWhichIsA("Animator", true)
		if not animator then continue end
		local function freeze(track: AnimationTrack)
			if snapshot.tracks[track] == nil then snapshot.tracks[track] = track.Speed end
			track:AdjustSpeed(0)
		end
		for _, track in animator:GetPlayingAnimationTracks() do freeze(track) end
		table.insert(snapshot.signals, animator.AnimationPlayed:Connect(freeze))
	end
end

function Scene.resume(player: Player, duration: number)
	local snapshot = snapshots[player]
	if not snapshot then return end
	for _, signal in snapshot.signals do signal:Disconnect() end
	for track, speed in snapshot.tracks do if track.IsPlaying then track:AdjustSpeed(speed) end end
	if snapshot.root and snapshot.root.Parent then snapshot.root.Anchored = snapshot.anchored == true end
	for _, model in units(player) do
		model:SetAttribute("DayPaused", nil)
		local busyUntil = model:GetAttribute("IdleBusyUntil")
		if type(busyUntil) == "number" then model:SetAttribute("IdleBusyUntil", busyUntil + duration) end
	end
	snapshots[player] = nil
end

return Scene
