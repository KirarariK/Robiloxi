--!strict
-- Paramètres de style des 7 Voies : ils pilotent les générateurs de clips pour que chaque Voie
-- se reconnaisse au premier coup d'œil (garde, amplitude, rythme, gestes signatures).

export type Style = {
	Id: string,
	Crouch: number, -- abaissement du bassin en garde (studs)
	Spread: number, -- écart des jambes (°)
	Stagger: number, -- pied droit avancé (°)
	Lean: number, -- inclinaison du buste (° ; négatif = vers l'avant)
	GuardPitch: number, -- élévation du bras armé en garde (°)
	GuardElbow: number, -- flexion du coude en garde (°)
	GuardYaw: number, -- buste tourné (°)
	BladeTilt: number, -- inclinaison de la lame en garde (poignet, °)
	TwoHanded: boolean, -- main gauche sur la poignée (lame simple)
	OffHandFencing: boolean, -- main libre levée derrière (Duelliste)
	SwingAmp: number, -- amplitude des coups
	SwingTwist: number, -- rotation du buste pendant les coups (°)
	SwingEase: string, -- accélération de la frappe
	Jitter: number, -- secousses erratiques (°, Tempête)
	PushGesture: boolean, -- paume poussée en avant (Équilibre)
	Acrobatic: boolean, -- saltos et bonds (Faucon)
	HeavyBody: boolean, -- frappes lourdes, appuis profonds (Riposte)
	Fluid: boolean, -- transitions sinusoïdales sans à-coups (Équilibre)
	IdlePeriod: number, -- période de la respiration (s)
	IdleBob: number, -- amplitude du rebond au repos (studs)
	Hop: number, -- bond pendant les coups (studs)
}

local LIST: { Style } = {
	{
		-- Origine : gestes amples, coupes franches, garde à deux mains médiane
		Id = "Origine",
		Crouch = 0.35,
		Spread = 9,
		Stagger = 14,
		Lean = -4,
		GuardPitch = 38,
		GuardElbow = 62,
		GuardYaw = -12,
		BladeTilt = -12,
		TwoHanded = true,
		OffHandFencing = false,
		SwingAmp = 1.3,
		SwingTwist = 46,
		SwingEase = "cubicIn",
		Jitter = 0,
		PushGesture = false,
		Acrobatic = false,
		HeavyBody = false,
		Fluid = false,
		IdlePeriod = 2.6,
		IdleBob = 0.04,
		Hop = 0,
	},
	{
		-- Duelliste : une main, buste de profil, main libre levée derrière, pointe vers l'adversaire
		Id = "Duelliste",
		Crouch = 0.25,
		Spread = 6,
		Stagger = 26,
		Lean = 2,
		GuardPitch = 62,
		GuardElbow = 24,
		GuardYaw = -38,
		BladeTilt = -58,
		TwoHanded = false,
		OffHandFencing = true,
		SwingAmp = 0.9,
		SwingTwist = 24,
		SwingEase = "cubicIn",
		Jitter = 0,
		PushGesture = false,
		Acrobatic = false,
		HeavyBody = false,
		Fluid = false,
		IdlePeriod = 2.2,
		IdleBob = 0.03,
		Hop = 0,
	},
	{
		-- Rempart : garde basse et compacte, lame en travers du corps, gestes courts
		Id = "Rempart",
		Crouch = 0.6,
		Spread = 14,
		Stagger = 10,
		Lean = -8,
		GuardPitch = 22,
		GuardElbow = 80,
		GuardYaw = -6,
		BladeTilt = 18,
		TwoHanded = true,
		OffHandFencing = false,
		SwingAmp = 0.85,
		SwingTwist = 28,
		SwingEase = "cubicIn",
		Jitter = 0,
		PushGesture = false,
		Acrobatic = false,
		HeavyBody = false,
		Fluid = false,
		IdlePeriod = 3.2,
		IdleBob = 0.02,
		Hop = 0,
	},
	{
		-- Faucon : sur la pointe des pieds, lame tenue en arrière, bonds, saltos aériens
		Id = "Faucon",
		Crouch = 0.45,
		Spread = 12,
		Stagger = 20,
		Lean = -14,
		GuardPitch = 18,
		GuardElbow = 40,
		GuardYaw = -20,
		BladeTilt = -70,
		TwoHanded = false,
		OffHandFencing = false,
		SwingAmp = 1.15,
		SwingTwist = 52,
		SwingEase = "expoIn",
		Jitter = 0,
		PushGesture = false,
		Acrobatic = true,
		HeavyBody = false,
		Fluid = false,
		IdlePeriod = 0.9,
		IdleBob = 0.12,
		Hop = 0.75,
	},
	{
		-- Riposte : lame haute au-dessus de l'épaule, appuis profonds, frappes lourdes à deux mains
		Id = "Riposte",
		Crouch = 0.55,
		Spread = 16,
		Stagger = 18,
		Lean = -6,
		GuardPitch = 128,
		GuardElbow = 70,
		GuardYaw = -24,
		BladeTilt = 30,
		TwoHanded = true,
		OffHandFencing = false,
		SwingAmp = 1.4,
		SwingTwist = 58,
		SwingEase = "expoIn",
		Jitter = 0,
		PushGesture = false,
		Acrobatic = false,
		HeavyBody = true,
		Fluid = false,
		IdlePeriod = 3.4,
		IdleBob = 0.05,
		Hop = 0,
	},
	{
		-- Équilibre : mouvements continus, main libre ouverte vers l'avant (poussées cinétiques)
		Id = "Equilibre",
		Crouch = 0.4,
		Spread = 11,
		Stagger = 16,
		Lean = -2,
		GuardPitch = 44,
		GuardElbow = 46,
		GuardYaw = -26,
		BladeTilt = -24,
		TwoHanded = false,
		OffHandFencing = false,
		SwingAmp = 1.1,
		SwingTwist = 38,
		-- sineIn : commit lisible sans perdre le caractère fluide (recovery reste sineIn côté clip)
		SwingEase = "sineIn",
		Jitter = 0,
		PushGesture = true,
		Acrobatic = false,
		HeavyBody = false,
		Fluid = true,
		IdlePeriod = 4,
		IdleBob = 0.06,
		Hop = 0,
	},
	{
		-- Tempête : posture voûtée, lame basse traînante, secousses frénétiques
		Id = "Tempete",
		Crouch = 0.5,
		Spread = 15,
		Stagger = 22,
		Lean = -18,
		GuardPitch = 12,
		GuardElbow = 30,
		GuardYaw = -30,
		BladeTilt = -40,
		TwoHanded = true,
		OffHandFencing = false,
		SwingAmp = 1.35,
		SwingTwist = 64,
		SwingEase = "expoIn",
		Jitter = 9,
		PushGesture = false,
		Acrobatic = false,
		HeavyBody = false,
		Fluid = false,
		IdlePeriod = 0.7,
		IdleBob = 0.05,
		Hop = 0.28,
	},
}

local byId: { [string]: Style } = {}
for _, s in LIST do
	byId[s.Id] = table.freeze(s)
end

local Styles = {}
Styles.List = table.freeze(LIST)
Styles.Default = "Origine"

function Styles.get(id: string?): Style
	return (id and byId[id]) or byId.Origine
end

return table.freeze(Styles)
