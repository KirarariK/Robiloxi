#!/usr/bin/env python3
"""Génère le Luau qui synchronise src/ dans Studio depuis GitHub (commit donné), selon default.project.json.

Usage : python3 scripts/gen_deploy.py <sha> > deploy.luau
Règles Rojo : *.server.lua → Script, *.client.lua → LocalScript, *.lua → ModuleScript, dossier → Folder.
Les instances absentes du dépôt sous chaque racine sont supprimées (synchronisation exacte).
"""
import json, os, sys

REPO = "KirarariK/Robiloxi"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def roots(tree, path):
    for k, v in tree.items():
        if k.startswith("$") or not isinstance(v, dict):
            continue
        if "$path" in v:
            yield path + [k], v["$path"]
        yield from roots(v, path + [k])

def entries(src, inst):
    out = []
    for dirpath, dirs, files in os.walk(os.path.join(ROOT, src)):
        dirs.sort()
        rel = os.path.relpath(dirpath, os.path.join(ROOT, src))
        parts = [] if rel == "." else rel.split(os.sep)
        for f in sorted(files):
            if not f.endswith(".lua"):
                continue
            if f.endswith(".server.lua"):
                name, cls = f[:-11], "Script"
            elif f.endswith(".client.lua"):
                name, cls = f[:-11], "LocalScript"
            else:
                name, cls = f[:-4], "ModuleScript"
            out.append({"url": os.path.join(src, *parts, f).replace(os.sep, "/"), "path": inst + parts, "name": name, "class": cls})
    return out

def main():
    sha = sys.argv[1]
    proj = json.load(open(os.path.join(ROOT, "default.project.json")))
    all_roots, files = [], []
    for inst, src in roots(proj["tree"], []):
        all_roots.append(inst)
        files += entries(src, inst)
    lua = []
    def q(s): return json.dumps(s, ensure_ascii=False)
    lua.append('local H = game:GetService("HttpService")')
    lua.append('local was = H.HttpEnabled H.HttpEnabled = true')
    lua.append(f'local BASE = "https://raw.githubusercontent.com/{REPO}/{sha}/"')
    lua.append("local ROOTS = {" + ",".join("{" + ",".join(q(p) for p in r) + "}" for r in all_roots) + "}")
    lua.append("local FILES = {")
    for e in files:
        lua.append("{%s,{%s},%s,%s}," % (q(e["url"]), ",".join(q(p) for p in e["path"]), q(e["name"]), q(e["class"])))
    lua.append("}")
    lua.append(r'''
local function svc(name) local ok, s = pcall(game.GetService, game, name) if ok and s then return s end return game:FindFirstChild(name) end
local function folderAt(path, create)
	local cur = svc(path[1])
	for i = 2, #path do
		local nxt = cur:FindFirstChild(path[i])
		if not nxt then
			if not create then return nil end
			nxt = Instance.new("Folder") nxt.Name = path[i] nxt.Parent = cur
		end
		cur = nxt
	end
	return cur
end
local keep, report = {}, {}
local ok, err = pcall(function()
	for _, r in ROOTS do keep[folderAt(r, true)] = true end
	-- téléchargements en parallèle (un appel séquentiel par fichier dépasserait le délai de l'outil)
	local srcs, pending, failed = {}, #FILES, nil
	for i, f in FILES do
		task.spawn(function()
			local okGet, body = pcall(H.GetAsync, H, BASE .. f[1], true)
			if okGet then srcs[i] = body else failed = f[1] .. " : " .. tostring(body) end
			pending -= 1
		end)
	end
	local deadline = os.clock() + 45
	while pending > 0 and os.clock() < deadline do task.wait(0.05) end
	assert(pending == 0 and not failed, "téléchargement incomplet : " .. tostring(failed or (pending .. " restants")))
	for i, f in FILES do
		local src = srcs[i]
		local parent = folderAt(f[2], true)
		local inst = parent:FindFirstChild(f[3])
		if inst and inst.ClassName ~= f[4] then inst:Destroy() inst = nil end
		if not inst then inst = Instance.new(f[4]) inst.Name = f[3] inst.Parent = parent end
		inst.Source = src
		keep[inst] = true
		local p = parent while p and p ~= game do keep[p] = true p = p.Parent end
		table.insert(report, f[3] .. ":" .. #src)
	end
	for _, r in ROOTS do
		local root = folderAt(r, false)
		for _, d in root:GetDescendants() do
			if (d:IsA("LuaSourceContainer") or d:IsA("Folder")) and not keep[d] and d.Parent then d:Destroy() end
		end
	end
end)
H.HttpEnabled = was
return (ok and "OK " or ("ERREUR " .. tostring(err) .. " ")) .. table.concat(report, " ")''')
    print("\n".join(lua))

main()
