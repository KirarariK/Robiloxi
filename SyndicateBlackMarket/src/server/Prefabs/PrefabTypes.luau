--!strict
--[[
	PrefabTypes.luau
	Types et constructeurs des données de prefabs générées par blender_scripts/*.py
	(modules Prefabs/Data/*.luau). Une seule description par asset sert à la fois à
	l'export FBX Blender et à l'assemblage en Parts dans Studio.
]]

export type PartKind = "Box" | "Cyl" | "Wedge" | "Ball"
export type AssetCategory = "Room" | "Cap" | "Hub" | "Prop" | "Loot" | "Weapon" | "Tool"
export type AttributeValue = string | number | boolean
export type AttributeMap = { [string]: AttributeValue }

export type PartDefinition = {
	Kind: PartKind,
	Name: string,
	Material: string,
	Position: Vector3,
	Size: Vector3,
	Rotation: Vector3,
	Flags: number,
	Group: string?,
}

export type MarkerDefinition = {
	Kind: string,
	Name: string,
	Position: Vector3,
	Rotation: Vector3,
	Size: Vector3,
	Attributes: AttributeMap?,
}

export type AssetDefinition = {
	Name: string,
	Category: AssetCategory,
	Folder: string,
	Bounds: Vector3,
	Attributes: AttributeMap?,
	Parts: { PartDefinition },
	Markers: { MarkerDefinition },
}

export type MaterialDefinition = {
	Color: Color3,
	Material: Enum.Material,
	Reflectance: number,
	Transparency: number,
	Emissive: boolean,
}

local PrefabTypes = {}

-- Drapeaux (doivent rester identiques à sbm_common.py)
PrefabTypes.Flags = table.freeze({
	NoCollide = 1,
	Light = 2,
	Breakable = 4,
	NoQuery = 8,
	Beam = 16,
})

function PrefabTypes.hasFlag(flags: number, flag: number): boolean
	return bit32.band(flags, flag) ~= 0
end

function PrefabTypes.part(
	kind: PartKind,
	name: string,
	material: string,
	position: Vector3,
	size: Vector3,
	rotation: Vector3,
	flags: number,
	group: string?
): PartDefinition
	return table.freeze({
		Kind = kind,
		Name = name,
		Material = material,
		Position = position,
		Size = size,
		Rotation = rotation,
		Flags = flags,
		Group = group,
	})
end

function PrefabTypes.marker(
	kind: string,
	name: string,
	position: Vector3,
	rotation: Vector3,
	size: Vector3,
	attributes: AttributeMap?
): MarkerDefinition
	return table.freeze({
		Kind = kind,
		Name = name,
		Position = position,
		Rotation = rotation,
		Size = size,
		Attributes = attributes,
	})
end

-- CFrame d'une primitive ou d'un marqueur (rotation en degrés, ordre fromOrientation).
function PrefabTypes.toCFrame(position: Vector3, rotation: Vector3): CFrame
	return CFrame.new(position)
		* CFrame.fromOrientation(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
end

return table.freeze(PrefabTypes)
