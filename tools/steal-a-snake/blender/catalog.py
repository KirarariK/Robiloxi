"""
Catalogue des 98 serpents de l'encyclopédie (image de référence, 7 lignes × 14 colonnes).

Chaque fiche décrit le modèle Blender (cartoon_snakes.py) ET l'espèce de jeu (SnakesConfig.lua est généré).
  cell     : case de l'image (R<ligne>C<colonne>)
  id, name : identifiant de jeu / nom affiché
  zone     : 1..15 (BiomesConfig) · rar : 1 Commun … 7 Secret
  body, belly, accent : couleurs (hex) · eye : iris · eye_style : cute | angry | cat | glow | sleepy | none
  pattern  : solid | bands | stripes | spots | speckle | rainbow | patch | galaxy | lava | flame | scales |
             candy | ice | water | stone | slime | bandage | ribs | pixel | robot | gold
  pal      : couleurs du motif
  head     : cute | viper | dragon | beak | skull | pumpkin | robot | pixel | clown | octopus | blob | toad
  horns    : nub | dragon | long | unicorn · crest : flame | wave | leaf | spikes | mohawk | frill | feather | mane | lava
  hat      : crown | crown_gem | party | wizard | bowler | propeller | safari | knight | nemes | fedora | flowers |
             mosaic | explorer
  wings    : feather | bat · tail : flame | leaf | tuft | spike | feather | fork | flower | crystal | gold
  fx       : effets modélisés (flames, lava, drips_ice, splash, lightning, sparkles, stars, slime, coins, leaves,
             flowers, aura, foam, bubbles)
  rbx      : effets Roblox (Fire, Sparkle, Stars, Bubbles, Ghost)
  heads    : nombre de têtes (hydre) · mat : smooth | neon | glass
"""

CATALOG = [
    # ───────── 1 · Jungle Émeraude ─────────
    dict(cell="R1C13", id="Green_Snake", name="Serpent Vert", zone=1, rar=1, body="3E9A2E", belly="B7E07A", accent="8AD24F", eye="3A2A10", pattern="solid", head="cute"),
    dict(cell="R4C2", id="Lime_Snake", name="Serpent Citron", zone=1, rar=2, body="6CC22A", belly="D4E27A", accent="A4E03A", eye="7A3A10", eye_style="angry", pattern="solid", head="viper"),
    dict(cell="R2C9", id="Jungle_Python", name="Python Tacheté", zone=1, rar=3, body="7DC044", belly="CDE07A", accent="2E6E2A", eye="C03A1A", eye_style="angry", pattern="spots", pal=["2E6E2A", "4F8F2E"], head="viper"),
    dict(cell="R4C3", id="Spiky_Snake", name="Serpent Épineux", zone=1, rar=4, body="5E9A3A", belly="E3D48A", accent="7DC04F", eye="2A1A0A", pattern="speckle", pal=["4A7E2C", "8CC060"], head="cute", crest="spikes"),
    dict(cell="R6C1", id="Leaf_Snake", name="Serpent Feuillage", zone=1, rar=5, body="2F7A3A", belly="C9DA6E", accent="5DAF4F", eye="E8C030", eye_style="cat", pattern="scales", pal=["276A33"], head="cute", fx=["leaves"], tail="leaf"),
    dict(cell="R3C1", id="Leafcrown_Snake", name="Serpent Couronne de Feuilles", zone=1, rar=6, body="4C8C3E", belly="D8D47E", accent="8CC060", eye="3A2010", pattern="scales", pal=["3E7A33"], head="cute", crest="leaf", rbx=["Sparkle"]),
    dict(cell="R7C11", id="Emerald_Dragon", name="Dragon Émeraude", zone=1, rar=7, body="3A9A3A", belly="C8E070", accent="8ADA4A", eye="E8D040", eye_style="angry", pattern="scales", pal=["2E8030"], head="dragon", crest="frill", horns="dragon", rbx=["Sparkle"]),

    # ───────── 2 · Désert des Dunes ─────────
    dict(cell="R4C13", id="Sand_Snake", name="Serpent des Sables", zone=2, rar=1, body="D9C08E", belly="F2E2B8", accent="A8865A", eye="3A2A1A", pattern="spots", pal=["A8865A", "8A6A42"], head="toad"),
    dict(cell="R7C13", id="Sandstone_Snake", name="Serpent de Grès Doré", zone=2, rar=2, body="B8924A", belly="E6C878", accent="8A6428", eye="3A2A10", eye_style="sleepy", pattern="stone", pal=["8A6428", "D8B460"], head="viper"),
    dict(cell="R4C12", id="Explorer_Snake", name="Serpent Explorateur", zone=2, rar=3, body="8C6440", belly="D8BC8A", accent="5E4228", eye="4A9A3A", pattern="speckle", pal=["6E4E30"], head="viper", hat="explorer", hat_col=["6E7A3A", "4E5A28"]),
    dict(cell="R3C14", id="Iron_Pharaoh", name="Pharaon de Fer", zone=2, rar=4, body="7E7A74", belly="D8BF88", accent="B8862E", eye="E0C060", pattern="bands", pal=["B8862E"], head="viper", hat="nemes", hat_col=["8A8680", "5E5A56"]),
    dict(cell="R7C9", id="Golden_Pharaoh", name="Pharaon Doré", zone=2, rar=5, body="B88E3A", belly="E8CC80", accent="7E5A22", eye="4AA8A0", pattern="scales", pal=["8A6428"], head="cute", hat="nemes", hat_col=["E0B040", "7AA0A8"], skin="A8B0B4"),
    dict(cell="R2C14", id="Blue_Pharaoh", name="Pharaon Bleu", zone=2, rar=6, body="5E8A98", belly="D8C890", accent="C8A050", eye="2A3A4A", pattern="bands", pal=["C8A050", "3A6A88"], head="cute", hat="nemes", hat_col=["D8B850", "3A6488"], skin="9AB4BC"),
    dict(cell="R4C14", id="Sun_Pharaoh", name="Pharaon Soleil", zone=2, rar=7, body="D8A030", belly="F2D27A", accent="2E5A9A", eye="2E5A9A", pattern="bands", pal=["2E5A9A", "F2D27A"], head="cute", hat="nemes", hat_col=["F2C040", "2E5A9A"], skin="E8B048", beard=True, rbx=["Sparkle"], mat="smooth"),

    # ───────── 3 · Marais Venimeux ─────────
    dict(cell="R3C3", id="Toad_Snake", name="Serpent Crapaud", zone=3, rar=1, body="9A6A3E", belly="E2C08A", accent="7A5030", eye="4AA060", pattern="speckle", pal=["7A5030", "B88A58"], head="toad"),
    dict(cell="R6C13", id="Grey_Ranger", name="Serpent Ranger", zone=3, rar=2, body="8A8A88", belly="C8C8C4", accent="5A5A58", eye="2A2A2A", pattern="speckle", pal=["6A6A68", "AAAAA6"], head="viper", hat="bowler", hat_col=["6A5A30", "4A3E22"]),
    dict(cell="R6C12", id="Safari_Snake", name="Serpent Safari", zone=3, rar=3, body="D8603A", belly="F2CE88", accent="F0A0A0", eye="2A6AA0", pattern="spots", pal=["F0A0A0", "B83A2A"], head="cute", hat="safari", hat_col=["7A8A3A", "C04030"]),
    dict(cell="R4C5", id="Dapper_Snake", name="Serpent Élégant", zone=3, rar=4, body="3A8AB0", belly="E8D49A", accent="2A5A80", eye="E8D040", eye_style="cat", pattern="spots", pal=["2A5A80"], head="viper", hat="bowler", hat_col=["5A4AA0", "E07030"]),
    dict(cell="R5C12", id="Propeller_Snake", name="Serpent Hélice", zone=3, rar=5, body="3A70B8", belly="E8D088", accent="2A4A90", eye="2A1A10", pattern="spots", pal=["6AA8E0"], head="cute", hat="propeller", hat_col=["E04040", "F0D040", "3070D0", "40A040"], rbx=["Sparkle"]),
    dict(cell="R6C11", id="Pumpkin_Snake", name="Serpent Citrouille", zone=3, rar=7, body="D8701E", belly="F2B050", accent="7A2A08", eye="F8D040", eye_style="none", pattern="bands", pal=["B85A14"], head="pumpkin", rbx=["Fire"]),

    # ───────── 4 · Toundra Givrée ─────────
    dict(cell="R7C2", id="Frost_Snake", name="Serpent Givré", zone=4, rar=1, body="9AD4F0", belly="E2F6FC", accent="5AA8D8", eye="2A4A6A", pattern="ice", pal=["C8ECFA", "6AB4E0"], head="cute"),
    dict(cell="R7C6", id="Sapphire_Snake", name="Serpent Saphir", zone=4, rar=2, body="2A4E90", belly="8AA8D0", accent="6A90C8", eye="F0D040", eye_style="cat", pattern="speckle", pal=["6A90C8", "A8C0E0"], head="viper"),
    dict(cell="R4C10", id="Ice_King", name="Roi des Glaces", zone=4, rar=3, body="5EB8C0", belly="E0F4F0", accent="A0E0D0", eye="2A3A4A", pattern="bands", pal=["E0F4F0"], head="viper", hat="crown", hat_col=["F0C040"]),
    dict(cell="R7C7", id="Crystal_Ice_Snake", name="Serpent Cristal", zone=4, rar=4, body="3AA8D8", belly="B8EEFA", accent="70CCEA", eye="E0F6FF", eye_style="glow", pattern="ice", pal=["B8EEFA", "1F7DAE"], head="cute", crest="frill", mat="glass", rbx=["Sparkle"]),
    dict(cell="R1C3", id="Glacier_Snake", name="Serpent Glacier", zone=4, rar=5, body="8DDDF3", belly="E6FAFE", accent="53B8E0", eye="2A6A8A", eye_style="angry", pattern="ice", pal=["BAF0FA", "53B8E0"], head="viper", fx=["drips_ice"], mat="glass", rbx=["Sparkle"]),
    dict(cell="R3C13", id="Snow_Spirit", name="Esprit des Neiges", zone=4, rar=6, body="70BEDF", belly="B1F3FD", accent="90DCF3", eye="2C678E", eye_style="sleepy", pattern="solid", head="blob", mat="glass", fx=["sparkles"], rbx=["Ghost", "Sparkle"]),
    dict(cell="R6C2", id="Silver_Dragon", name="Dragon d'Argent", zone=4, rar=7, body="C8C8CC", belly="E8E8EA", accent="A1A2AB", eye="4AA060", pattern="scales", pal=["A1A2AB"], head="dragon", horns="dragon", crest="spikes", rbx=["Sparkle"]),

    # ───────── 5 · Forêt de Bambous ─────────
    dict(cell="R3C6", id="Pastel_Snake", name="Serpent Pastel", zone=5, rar=1, body="F2B8A8", belly="F8E0C8", accent="76C5B7", eye="2A2A3A", pattern="bands", pal=["F2B8A8", "76C5B7", "F8D8A0"], head="cute", head_col="70D0C8"),
    dict(cell="R2C10", id="Pastel_Rainbow", name="Arc-en-ciel Pastel", zone=5, rar=2, body="C9A0C8", belly="F2E8D8", accent="8AB8E0", eye="2A2A3A", pattern="rainbow", pal=["F0A0A0", "F8D0A0", "F8F0A0", "A0E0B0", "A0C8F0", "C8A8F0"], head="cute"),
    dict(cell="R4C7", id="Rainbow_Snake", name="Serpent Arc-en-ciel", zone=5, rar=3, body="E86A6A", belly="F8E0B0", accent="6AA8E8", eye="2A2A3A", pattern="rainbow", pal=["E85A5A", "F0A040", "F0E050", "60C870", "5AA0E8", "A070D8"], head="cute"),
    dict(cell="R5C3", id="Candy_Snake", name="Serpent Sucre d'Orge", zone=5, rar=4, body="F2EDEA", belly="F8F4F2", accent="E05A6A", eye="2A2A3A", pattern="candy", pal=["E05A6A", "60C0D0"], head="cute"),
    dict(cell="R1C8", id="Rainbow_Princess", name="Princesse Arc-en-ciel", zone=5, rar=5, body="F0A0B8", belly="F8E0C8", accent="E06A6A", eye="4AA8C8", pattern="rainbow", pal=["F06A6A", "F0A040", "F0E050", "60C870", "5AA0E8", "8A70D8"], head="cute", head_col="F0A8C0", hat="crown", hat_col=["F0C040"], tail="feather", rbx=["Sparkle"]),
    dict(cell="R6C3", id="Unicorn_Snake", name="Serpent Licorne", zone=5, rar=7, body="E8C870", belly="F8E8B0", accent="E070B0", eye="2A2A6A", pattern="patch", pal=["E07070", "70B0E0", "A070D0", "70D090", "F0D060"], head="cute", horns="unicorn", crest="mane", tail="tuft", rbx=["Sparkle", "Stars"]),

    # ───────── 6 · Canyon Rouge ─────────
    dict(cell="R3C4", id="Earth_Dragon", name="Dragon de Terre", zone=6, rar=1, body="7A5030", belly="B8946A", accent="5E3A20", eye="40C0C0", eye_style="glow", pattern="scales", pal=["603B23"], head="dragon", horns="long"),
    dict(cell="R2C4", id="Stone_Snake", name="Serpent de Pierre", zone=6, rar=2, body="8A7E72", belly="B0A494", accent="5E544A", eye="E0A030", eye_style="angry", pattern="stone", pal=["5E544A", "A89C8E"], head="viper"),
    dict(cell="R5C2", id="Robo_Snake", name="Robo-Serpent", zone=6, rar=3, body="A8BCC8", belly="D8E4EC", accent="40D8E0", eye="40E0F0", eye_style="glow", pattern="robot", pal=["6A8298", "40D8E0"], head="robot", rbx=["Sparkle"]),
    dict(cell="R2C12", id="Knight_Snake", name="Serpent Chevalier", zone=6, rar=4, body="6A6062", belly="C8B8A0", accent="D07A30", eye="F0A030", pattern="scales", pal=["8F827F"], head="viper", hat="knight", hat_col=["9A9AA0", "6A6A70"], tail="spike"),
    dict(cell="R5C14", id="Fang_Snake", name="Serpent Crocs", zone=6, rar=5, body="3A3236", belly="8A7E70", accent="E8E4D8", eye="4AC060", eye_style="angry", pattern="scales", pal=["2D2226"], head="viper", fangs=True),
    dict(cell="R1C7", id="Red_Dragon", name="Dragon Rouge", zone=6, rar=7, body="C83A30", belly="EDB473", accent="F0C080", eye="5AC060", pattern="scales", pal=["AA2F2D"], head="dragon", horns="dragon", wings="bat", rbx=["Fire"]),

    # ───────── 7 · Bois aux Champignons ─────────
    dict(cell="R4C6", id="Pink_Snake", name="Serpent Rose", zone=7, rar=1, body="F2A8C0", belly="F8D8E2", accent="DA8CA7", eye="2A3A5A", pattern="solid", head="cute"),
    dict(cell="R7C12", id="Coral_Pink_Snake", name="Serpent Corail Rose", zone=7, rar=2, body="E86A68", belly="F6C090", accent="C63F41", eye="2A1A10", pattern="speckle", pal=["C63F41", "F08880"], head="viper"),
    dict(cell="R1C10", id="Party_Snake", name="Serpent Fêtard", zone=7, rar=3, body="EDB7C2", belly="F8E2D8", accent="C37F9D", eye="2A4A8A", pattern="spots", pal=["C37F9D", "F8E0E8"], head="cute", hat="party", hat_col=["F8D8E0", "E07090", "F0E060"], tail="feather"),
    dict(cell="R5C8", id="Clown_Snake", name="Serpent Clown", zone=7, rar=4, body="F0EBDE", belly="F8F4EA", accent="E04030", eye="3A8AC0", pattern="bands", pal=["E04030", "F0B030", "40A060", "3A8AC0"], head="clown", hat="party", hat_col=["F0E0B0", "40A060", "E04030"]),
    dict(cell="R5C9", id="Patchwork_Snake", name="Serpent Patchwork", zone=7, rar=5, body="C8A060", belly="F2E0A8", accent="E07030", eye="2A2A3A", pattern="patch", pal=["E06060", "F0B040", "70C060", "5A90D8", "A070C8"], head="cute", crest="flower_tuft", tail="flower"),
    dict(cell="R1C14", id="Wizard_Snake", name="Serpent Sorcier", zone=7, rar=7, body="C83A30", belly="ECC08C", accent="7A3A9A", eye="2A1A10", pattern="speckle", pal=["A42127"], head="cute", hat="wizard", hat_col=["6A4AA8", "F0D060"], rbx=["Sparkle", "Stars"]),

    # ───────── 8 · Récif Corallien ─────────
    dict(cell="R1C4", id="Water_Snake", name="Serpent d'Eau", zone=8, rar=1, body="359DC8", belly="B6F0F7", accent="73CCE2", eye="1A3A5A", eye_style="angry", pattern="water", pal=["73CCE2", "257AA4"], head="viper", crest="wave", fx=["splash"], mat="glass"),
    dict(cell="R4C4", id="Wave_Snake", name="Serpent Vague", zone=8, rar=2, body="4DACCC", belly="B9E5EA", accent="72CCE8", eye="1A3A5A", eye_style="angry", pattern="water", pal=["B9E5EA", "3283AA"], head="viper", crest="wave", fx=["drips_ice"], mat="glass"),
    dict(cell="R5C10", id="Coral_Snake", name="Serpent Corail", zone=8, rar=3, body="C84A4E", belly="E7B191", accent="F08AA0", eye="40B0A0", pattern="spots", pal=["F08AA0", "8B303A"], head="cute", crest="flower_tuft", tail="flower"),
    dict(cell="R4C8", id="Mohawk_Snake", name="Serpent Crête d'Algue", zone=8, rar=4, body="2E8E68", belly="7ACB8A", accent="63E05C", eye="5A3A1A", pattern="bands", pal=["7ACB8A"], head="cute", crest="mohawk"),
    dict(cell="R1C5", id="Tidal_Snake", name="Serpent Raz-de-Marée", zone=8, rar=5, body="2685A9", belly="94E5F7", accent="60CFE3", eye="1A3A5A", eye_style="angry", pattern="water", pal=["60CFE3", "1E6E90"], head="viper", crest="wave", fx=["foam", "splash"], mat="glass", rbx=["Bubbles"]),
    dict(cell="R5C11", id="Octopus", name="Pieuvre Mystique", zone=8, rar=6, body="9A62C8", belly="C890E8", accent="5E3B83", eye="E8E040", pattern="spots", pal=["C890E8"], head="octopus", rbx=["Bubbles"]),
    dict(cell="R1C9", id="Sea_Hydra", name="Hydre des Mers", zone=8, rar=7, body="3A8A6A", belly="95DA9D", accent="71BB88", eye="F0D040", eye_style="angry", pattern="scales", pal=["2A6A5A"], head="dragon", heads=5, crest="frill", rbx=["Bubbles", "Sparkle"]),

    # ───────── 9 · Caldeira Volcanique ─────────
    dict(cell="R7C1", id="Ember_Snake", name="Serpent Braise", zone=9, rar=1, body="D85625", belly="F3C262", accent="A4240A", eye="3A1A0A", eye_style="angry", pattern="flame", pal=["F08A30", "A4240A"], head="viper"),
    dict(cell="R4C1", id="Flamehorn_Snake", name="Serpent Cornes de Feu", zone=9, rar=2, body="C8402E", belly="F7CA68", accent="F0A030", eye="3A1A0A", pattern="scales", pal=["AA1E11"], head="cute", horns="flame", tail="flame", rbx=["Fire"]),
    dict(cell="R2C2", id="Lava_Rock_Snake", name="Serpent Roche-Lave", zone=9, rar=3, body="5E4A48", belly="F0A040", accent="ED8F34", eye="F0C040", eye_style="glow", pattern="lava", pal=["ED8F34", "FBBF37"], head="viper", fx=["lava"], rbx=["Fire"]),
    dict(cell="R5C1", id="Baby_Fire_Dragon", name="Bébé Dragon de Feu", zone=9, rar=4, body="CF4729", belly="F4C06A", accent="DD7C48", eye="3A1A0A", pattern="scales", pal=["A71C09"], head="dragon", horns="nub", tail="flame", rbx=["Fire"]),
    dict(cell="R2C1", id="Fire_Dragon", name="Dragon de Feu", zone=9, rar=5, body="D0502A", belly="F3C25B", accent="F08A30", eye="3A1A0A", eye_style="angry", pattern="flame", pal=["F08A30", "A32107"], head="dragon", horns="dragon", crest="flame", rbx=["Fire"]),
    dict(cell="R1C2", id="Magma_Snake", name="Serpent de Magma", zone=9, rar=6, body="2A1A18", belly="FBBF37", accent="EC8940", eye="FBBF37", eye_style="glow", pattern="lava", pal=["EC8940", "FBBF37"], head="viper", fx=["lava", "flames"], rbx=["Fire"]),
    dict(cell="R1C1", id="Living_Flame", name="Flamme Vivante", zone=9, rar=7, body="E8641E", belly="F8B840", accent="F8E070", eye="7A2A08", eye_style="angry", pattern="flame", pal=["FBC737", "B83A14"], head="viper", crest="flame", tail="flame", fx=["flames"], mat="smooth", rbx=["Fire", "Sparkle"]),

    # ───────── 10 · Grotte de Cristal ─────────
    dict(cell="R6C4", id="Patch_King", name="Roi Patchwork", zone=10, rar=1, body="CBC08B", belly="F2E2B0", accent="5273A4", eye="2A2A3A", pattern="patch", pal=["E07070", "5273A4", "70C080", "F0C050", "A070C0"], head="cute", hat="crown", hat_col=["E0A030"]),
    dict(cell="R6C5", id="Glitter_Snake", name="Serpent Paillettes", zone=10, rar=2, body="D8A848", belly="F2D888", accent="E070A0", eye="2A2A3A", pattern="patch", pal=["E07090", "70B0E0", "A080D0", "F0D060"], head="cute", hat="mosaic", hat_col=["E07090", "70B0E0", "F0D060"], fx=["sparkles"], rbx=["Sparkle"]),
    dict(cell="R7C3", id="Blossom_Snake", name="Serpent Fleuri", zone=10, rar=3, body="7AB848", belly="D8E07A", accent="F08AB8", eye="2A1A10", pattern="speckle", pal=["5A9A30"], head="cute", hat="flowers", hat_col=["F08AB8", "F8C0D8"], fx=["flowers"]),
    dict(cell="R7C4", id="Lavender_Snake", name="Serpent Lavande", zone=10, rar=4, body="A884D0", belly="F0D890", accent="F07890", eye="2A1A3A", pattern="bands", pal=["9B81B5"], head="cute", hat="flowers", hat_col=["F07890", "F8B0A0"], belly_rainbow=True),
    dict(cell="R6C14", id="Flower_King", name="Roi des Fleurs", zone=10, rar=5, body="5AAA48", belly="E8D47E", accent="E070A0", eye="3A1A10", pattern="spots", pal=["E070A0"], head="cute", hat="crown_gem", hat_col=["F0C040", "40B060"], fx=["flowers"], rbx=["Sparkle"]),
    dict(cell="R3C11", id="Golden_Crown_Snake", name="Serpent d'Or Couronné", zone=10, rar=7, body="E8A830", belly="F7D65C", accent="B36E20", eye="4AA8C8", pattern="scales", pal=["D08A20"], head="cute", hat="crown_gem", hat_col=["F0C040", "4AA8E0"], tail="flame", mat="smooth", rbx=["Sparkle"]),

    # ───────── 11 · Cimetière Hanté ─────────
    dict(cell="R7C5", id="Mummy_Snake", name="Serpent Momie", zone=11, rar=1, body="EAD7AB", belly="F2E4C0", accent="98855B", eye="4AA060", pattern="bandage", pal=["C0AB7F"], head="cute", mummy=True, skin="5A8A5A"),
    dict(cell="R6C7", id="Bandaged_Snake", name="Serpent Bandelettes", zone=11, rar=2, body="E6D8B4", belly="F2E8CC", accent="9D8F6E", eye="40C060", eye_style="glow", pattern="bandage", pal=["C6B895"], head="cute", mummy=True, skin="3A4A3A"),
    dict(cell="R3C12", id="Bone_Serpent", name="Serpent d'Os", zone=11, rar=3, body="D8D4B0", belly="ECE8CC", accent="9F9A70", eye="50E070", eye_style="glow", pattern="scales", pal=["AFAA83"], head="skull"),
    dict(cell="R3C9", id="Skeleton_Snake", name="Serpent Squelette", zone=11, rar=4, body="E3DDC2", belly="E3DDC2", accent="6E6455", eye="40E060", eye_style="glow", pattern="ribs", head="skull", rbx=["Ghost"]),
    dict(cell="R3C10", id="Ancient_Skeleton", name="Squelette Ancien", zone=11, rar=5, body="D0D9B3", belly="D0D9B3", accent="46623C", eye="30F070", eye_style="glow", pattern="ribs", head="skull", rbx=["Ghost", "Sparkle"]),
    dict(cell="R5C13", id="Shadow_Gangster", name="Gangster de l'Ombre", zone=11, rar=6, body="3A1A5A", belly="5B1F8A", accent="AD57D9", eye="F0D040", eye_style="glow", pattern="solid", head="viper", hat="fedora", hat_col=["3A2A5A", "8A4AC0"], fx=["aura"], mat="neon", rbx=["Ghost"]),
    dict(cell="R3C8", id="Shadow_Dragon", name="Dragon des Ténèbres", zone=11, rar=7, body="281040", belly="551884", accent="AF5BDB", eye="F070F0", eye_style="glow", pattern="solid", head="dragon", horns="dragon", fx=["aura"], rbx=["Ghost", "Sparkle"]),

    # ───────── 12 · Temple Aztèque ─────────
    dict(cell="R2C13", id="Cream_King", name="Roi Crème", zone=12, rar=1, body="E8C898", belly="F6E6C4", accent="9A5A3A", eye="4AA0C0", pattern="spots", pal=["9A5A3A", "C07A5A"], head="cute", hat="crown_gem", hat_col=["F0C040", "E04040"]),
    dict(cell="R6C9", id="Green_King", name="Roi Vert", zone=12, rar=2, body="3E8A48", belly="E2D890", accent="B8A860", eye="5A3A1A", pattern="spots", pal=["B8A860"], head="viper", hat="crown", hat_col=["F0C040"]),
    dict(cell="R6C8", id="Turquoise_King", name="Roi Turquoise", zone=12, rar=3, body="4AA88A", belly="E2E0A0", accent="2E7A68", eye="6A3A2A", pattern="scales", pal=["3A8A78"], head="cute", hat="crown_gem", hat_col=["F0C040", "E04040"]),
    dict(cell="R6C10", id="Sparkle_King", name="Roi Étincelant", zone=12, rar=4, body="6EA83A", belly="D8E080", accent="B8E060", eye="3A2A10", pattern="spots", pal=["B8E060", "456514"], head="viper", hat="crown", hat_col=["F0C040"], fx=["sparkles"], rbx=["Sparkle"]),
    dict(cell="R7C10", id="Temple_Pharaoh", name="Pharaon du Temple", zone=12, rar=5, body="5A8A98", belly="E8D090", accent="C89A40", eye="3A6A88", pattern="bands", pal=["C89A40", "2E5A88"], head="cute", hat="nemes", hat_col=["D8B850", "2E6A98"], skin="E0C8A8", rbx=["Sparkle"]),
    dict(cell="R3C5", id="Mage_Snake", name="Serpent Mage", zone=12, rar=6, body="7A5A98", belly="E3C493", accent="4A3A88", eye="3A2A10", pattern="solid", head="cute", head_col="C8A070", hat="wizard", hat_col=["3A4A90", "F0D060"], rbx=["Stars"]),
    dict(cell="R7C14", id="Treasure_Snake", name="Serpent Trésor", zone=12, rar=7, body="F2C83A", belly="F8E070", accent="CA8F1D", eye="8A5A10", eye_style="sleepy", pattern="gold", pal=["F8DF70", "CA8F1D"], head="cute", tail="gold", fx=["coins", "sparkles"], rbx=["Sparkle"]),

    # ───────── 13 · Marécage Toxique ─────────
    dict(cell="R5C5", id="Pixel_Snake", name="Serpent Pixel", zone=13, rar=1, body="4BB43D", belly="84C94B", accent="1B751F", eye="1A1A1A", pattern="pixel", pal=["1B751F", "84C94B"], head="pixel"),
    dict(cell="R6C6", id="Bigeye_Snake", name="Serpent Gros Yeux", zone=13, rar=2, body="5AB838", belly="B8DA6A", accent="2F7613", eye="F0C020", eye_style="cat", pattern="solid", head="cute", big_eyes=True),
    dict(cell="R4C9", id="Slime_Snake", name="Serpent Gluant", zone=13, rar=3, body="62DD2B", belly="A6F06A", accent="1C9109", eye="1A3A0A", eye_style="angry", pattern="slime", pal=["86EF47", "3BBE18"], head="viper", fx=["slime"], mat="glass", rbx=["Bubbles"]),
    dict(cell="R5C6", id="Toxic_Snake", name="Serpent Toxique", zone=13, rar=4, body="4A9A30", belly="A5CE6A", accent="82DA2D", eye="1A1A0A", eye_style="angry", pattern="spots", pal=["2E6E1A"], head="viper", fx=["slime"], rbx=["Bubbles"]),
    dict(cell="R5C7", id="Slime_Blob", name="Blob Visqueux", zone=13, rar=5, body="6ACF32", belly="A2EF4A", accent="2B8B19", eye="1A3A0A", eye_style="angry", pattern="slime", pal=["A2EF4A", "4CBC15"], head="blob", fx=["slime"], mat="glass", rbx=["Bubbles"]),
    dict(cell="R3C7", id="Moss_Dragon", name="Dragon des Mousses", zone=13, rar=6, body="48A033", belly="BFE96F", accent="86DF3A", eye="E8E040", eye_style="angry", pattern="scales", pal=["2A7C28"], head="dragon", crest="leaf", tail="leaf", fx=["leaves"], rbx=["Bubbles"]),
    dict(cell="R5C4", id="Toxic_Robot", name="Robot Toxique", zone=13, rar=7, body="8A9A98", belly="B4C0A7", accent="40E070", eye="40F070", eye_style="glow", pattern="robot", pal=["4F6262", "40E070"], head="robot", rbx=["Bubbles", "Sparkle"]),

    # ───────── 14 · Royaume Céleste ─────────
    dict(cell="R3C2", id="Thunder_Snake", name="Serpent Éclair", zone=14, rar=1, body="7888B7", belly="BDE0F7", accent="F0F070", eye="2A3A5A", pattern="speckle", pal=["526994", "95B3D5"], head="viper", fx=["lightning"], rbx=["Sparkle"]),
    dict(cell="R2C3", id="Thunder_Dragon", name="Dragon du Tonnerre", zone=14, rar=2, body="3A9A6A", belly="E8D888", accent="E07A30", eye="E8A030", pattern="scales", pal=["2E7A55"], head="dragon", horns="dragon", crest="frill", fx=["lightning"], rbx=["Sparkle"]),
    dict(cell="R1C6", id="Phoenix", name="Phénix", zone=14, rar=3, body="C83A2A", belly="F0B060", accent="F0A040", eye="F0D040", pattern="scales", pal=["A0332A"], head="beak", crest="feather", wings="feather", tail="feather", rbx=["Fire"]),
    dict(cell="R2C7", id="Golden_Phoenix", name="Phénix Doré", zone=14, rar=4, body="E06A2A", belly="F4C060", accent="F8D060", eye="F0D040", pattern="scales", pal=["C04A20"], head="beak", crest="feather", wings="feather", tail="feather", rbx=["Fire", "Sparkle"]),
    dict(cell="R2C5", id="Storm_Hydra", name="Hydre de l'Orage", zone=14, rar=5, body="6070A0", belly="B1C3E9", accent="8895C1", eye="F0F0A0", eye_style="glow", pattern="scales", pal=["404972"], head="dragon", heads=2, crest="frill", fx=["lightning"], rbx=["Sparkle"]),
    dict(cell="R4C11", id="Silver_Flame_King", name="Roi d'Argent", zone=14, rar=7, body="8A8680", belly="C2B7A6", accent="E0A030", eye="4AA060", pattern="scales", pal=["6A6055"], head="viper", hat="crown", hat_col=["F0B030"], fx=["flames"], rbx=["Fire", "Sparkle"]),

    # ───────── 15 · Néant Cosmique ─────────
    dict(cell="R2C8", id="Void_Snake", name="Serpent du Vide", zone=15, rar=1, body="1A0A2A", belly="3A1A5A", accent="B04CD6", eye="E0B0FF", eye_style="glow", pattern="solid", head="cute", fx=["aura"], mat="neon", rbx=["Ghost"]),
    dict(cell="R7C8", id="Night_Dragon", name="Dragon de la Nuit", zone=15, rar=2, body="2A1040", belly="561886", accent="C065ED", eye="F080F0", eye_style="glow", pattern="solid", head="dragon", horns="nub", fx=["aura"], rbx=["Ghost"]),
    dict(cell="R2C6", id="Eclipse_Dragon", name="Dragon Éclipse", zone=15, rar=3, body="301050", belly="6F28A2", accent="AE52DC", eye="F0D0FF", eye_style="glow", pattern="solid", head="dragon", crest="frill", fx=["aura"], rbx=["Ghost", "Sparkle"]),
    dict(cell="R2C11", id="Galaxy_Queen", name="Reine Galaxie", zone=15, rar=4, body="2A2470", belly="433B9A", accent="B060F0", eye="F0D060", eye_style="glow", pattern="galaxy", pal=["8344B4", "DCB9C7"], head="cute", hat="crown", hat_col=["F0C040"], fx=["stars"], rbx=["Stars"]),
    dict(cell="R1C11", id="Twin_Shadow", name="Hydre Jumelle", zone=15, rar=5, body="3A2A50", belly="61416A", accent="A047CF", eye="F09040", eye_style="glow", pattern="scales", pal=["502887"], head="dragon", heads=2, horns="dragon", fx=["aura"], rbx=["Ghost", "Stars"]),
    dict(cell="R1C12", id="Galaxy_King", name="Roi Galaxie", zone=15, rar=7, body="352978", belly="4E3F97", accent="8A9AF0", eye="F0D060", eye_style="glow", pattern="galaxy", pal=["999DDA", "D1B073"], head="cute", hat="crown", hat_col=["F0C040"], fx=["stars"], rbx=["Stars", "Sparkle"]),
]
