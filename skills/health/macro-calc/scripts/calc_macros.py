#!/usr/bin/env python3
"""
Macro Calculator — TACO (UNICAMP) + Manual DB
Busca deterministica por alias → descricao TACO exata.
Zero fuzzy matching. Se nao achar, retorna NOT_FOUND.

Uso:
  python3 calc_macros.py '{"items": [{"name": "arroz", "grams": 200}]}'

Saida: JSON com macros por item + total
"""

import json
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TACO_PATH = os.path.join(SCRIPT_DIR, "..", "TACO.json")

# ============================================================
# ALIAS MAP: nome curto/comum → descricao EXATA na TACO
# Sempre versao cozida/grelhada quando disponivel
# ============================================================
ALIAS_MAP = {
    # --- Carnes bovinas ---
    "patinho": "Carne, bovina, patinho, sem gordura, grelhado",
    "patinho moido": "Carne, bovina, patinho, sem gordura, grelhado",
    "patinho grelhado": "Carne, bovina, patinho, sem gordura, grelhado",
    "acem": "Carne, bovina, acém, sem gordura, cozido",
    "acem moido": "Carne, bovina, acém, moído, cozido",
    "coxao mole": "Carne, bovina, coxão mole, sem gordura, cozido",
    "coxao duro": "Carne, bovina, coxão duro, sem gordura, cozido",
    "alcatra": "Carne, bovina, miolo de alcatra, sem gordura, grelhado",
    "contra file": "Carne, bovina, contra-filé, sem gordura, grelhado",
    "contrafile": "Carne, bovina, contra-filé, sem gordura, grelhado",
    "file mignon": "Carne, bovina, filé mingnon, sem gordura, grelhado",
    "maminha": "Carne, bovina, maminha, grelhada",
    "lagarto": "Carne, bovina, lagarto, cozido",
    "musculo": "Carne, bovina, músculo, sem gordura, cozido",
    "cupim": "Carne, bovina, cupim, assado",
    "peito bovino": "Carne, bovina, peito, sem gordura, cozido",
    "figado bovino": "Carne, bovina, fígado, grelhado",
    "figado": "Carne, bovina, fígado, grelhado",
    "carne moida": "Carne, bovina, acém, moído, cozido",
    "carne de sol": "Carne, bovina, charque, cozido",

    # --- Frango ---
    "frango": "Frango, peito, sem pele, cozido",
    "peito de frango": "Frango, peito, sem pele, cozido",
    "file de frango": "Frango, peito, sem pele, cozido",
    "frango grelhado": "Frango, peito, sem pele, cozido",
    "frango cozido": "Frango, inteiro, sem pele, cozido",
    "coxa de frango": "Frango, coxa, sem pele, cozida",
    "sobrecoxa": "Frango, sobrecoxa, sem pele, assada",
    "sobrecoxa de frango": "Frango, sobrecoxa, sem pele, assada",
    "frango caipira": "Frango, caipira, inteiro, sem pele, cozido",

    # --- Ovos ---
    "ovo": "Ovo, de galinha, inteiro, cozido/10minutos",
    "ovos": "Ovo, de galinha, inteiro, cozido/10minutos",
    "ovo cozido": "Ovo, de galinha, inteiro, cozido/10minutos",
    "ovo frito": "Ovo, de galinha, inteiro, frito",
    "clara": "Ovo, de galinha, clara, cozida/10minutos",
    "clara de ovo": "Ovo, de galinha, clara, cozida/10minutos",
    "gema": "Ovo, de galinha, gema, cozida/10minutos",
    "ovo de codorna": "Ovo, de codorna, inteiro, cru",

    # --- Arroz ---
    "arroz": "Arroz, tipo 1, cozido",
    "arroz branco": "Arroz, tipo 1, cozido",
    "arroz integral": "Arroz, integral, cozido",

    # --- Feijao ---
    "feijao": "Feijão, carioca, cozido",
    "feijao carioca": "Feijão, carioca, cozido",
    "feijao preto": "Feijão, preto, cozido",

    # --- Pao ---
    "pao integral": "Pão, trigo, forma, integral",
    "pao de forma": "Pão, trigo, forma, integral",
    "pao de forma integral": "Pão, trigo, forma, integral",
    "pao frances": "Pão, trigo, francês",
    "pao de queijo": "Pão, de queijo, assado",
    "pao de aveia": "Pão, aveia, forma",
    "torrada": "Torrada, pão francês",

    # --- Massas ---
    "macarrao": "Macarrão, trigo, cru",
    "macarrao cozido": "Macarrão, trigo, cru",
    "macarrao instantaneo": "Macarrão, instantâneo",

    # --- Tuberculos ---
    "batata doce": "Batata, doce, cozida",
    "batata": "Batata, inglesa, cozida",
    "batata inglesa": "Batata, inglesa, cozida",
    "batata cozida": "Batata, inglesa, cozida",
    "mandioca": "Mandioca, cozida",
    "inhame": "Inhame, cru",

    # --- Leite e derivados ---
    "leite integral": "Leite, de vaca, integral",
    "leite desnatado": "Leite, de vaca, desnatado, UHT",
    "leite": "Leite, de vaca, integral",
    "queijo minas": "Queijo, minas, frescal",
    "queijo mussarela": "Queijo, mozarela",
    "mussarela": "Queijo, mozarela",
    "queijo prato": "Queijo, prato",
    "queijo parmesao": "Queijo, prato",
    "manteiga": "Manteiga, com sal",
    "creme de leite": "Creme de Leite",
    "leite condensado": "Leite, condensado",

    # --- Frutas ---
    "banana": "Banana, nanica, crua",
    "banana nanica": "Banana, nanica, crua",
    "banana prata": "Banana, prata, crua",
    "banana maca": "Banana, maçã, crua",
    "maca": "Maçã, Fuji, com casca, crua",
    "laranja": "Laranja, baía, crua",
    "mamao": "Mamão, papaia, cru",
    "melancia": "Melancia, crua",
    "melao": "Melão, cru",
    "abacaxi": "Abacaxi, cru",
    "manga": "Manga, Palmer, crua",
    "uva": "Uva, rubi, crua",
    "morango": "Morango, cru",
    "goiaba": "Goiaba, branca, com casca, crua",
    "abacate": "Abacate, cru",
    "kiwi": "Kiwi, cru",

    # --- Verduras e legumes ---
    "tomate": "Tomate, com semente, cru",
    "alface": "Alface, crespa, crua",
    "brocolis": "Brócolis, cozido",
    "couve": "Couve, manteiga, crua",
    "couve refogada": "Couve, manteiga, refogada",
    "cenoura": "Cenoura, crua",
    "cenoura cozida": "Cenoura, cozida",
    "abobora": "Abóbora, moranga, refogada",
    "chuchu": "Chuchu, cozido",
    "espinafre": "Espinafre, Nova Zelândia, cru",
    "pepino": "Pepino, cru",
    "cebola": "Cebola, crua",
    "pimentao": "Pimentão, verde, cru",

    # --- Oleaginosas e gorduras ---
    "azeite": "Azeite, de oliva, extra virgem",
    "azeite de oliva": "Azeite, de oliva, extra virgem",
    "oleo de soja": "Óleo, de soja",
    "castanha do para": "Castanha-do-Brasil, crua",
    "amendoim": "Amendoim, grão, cru",

    # --- Cereais ---
    "aveia": "Aveia, flocos, crua",
    "flocos de aveia": "Aveia, flocos, crua",

    # --- Embutidos ---
    "presunto": "Presunto, sem capa de gordura",
    "linguica": "Lingüiça, porco, grelhada",
    "linguica de frango": "Lingüiça, frango, grelhada",

    # --- Peixes ---
    "atum": "Atum, conserva em óleo",
    "atum em lata": "Atum, conserva em óleo",
    "sardinha": "Sardinha, conserva em óleo",
    "salmao": "Salmão, sem pele, fresco, grelhado",
    "salmao grelhado": "Salmão, sem pele, fresco, grelhado",

    # --- Doces ---
    "doce de leite": "Doce, de leite, cremoso",
    "acucar": "Açúcar, cristal",
    "mel": "Mel, de abelha",

    # --- Sucos ---
    "suco de laranja": "Laranja, baía, suco",

    # --- Outros ---
    "farofa": "Mandioca, farofa, temperada",
    "pipoca": "Pipoca, com óleo de soja, sem sal",
}

# Alimentos industrializados NAO presentes na TACO (valores por 100g)
MANUAL_DB = {
    "whey protein": {"energy_kcal": 375, "protein_g": 80, "lipid_g": 4, "carbohydrate_g": 8, "fiber_g": 0},
    "whey": {"energy_kcal": 375, "protein_g": 80, "lipid_g": 4, "carbohydrate_g": 8, "fiber_g": 0},
    "requeijao cremoso": {"energy_kcal": 257, "protein_g": 7, "lipid_g": 24, "carbohydrate_g": 3, "fiber_g": 0},
    "requeijao": {"energy_kcal": 257, "protein_g": 7, "lipid_g": 24, "carbohydrate_g": 3, "fiber_g": 0},
    "pasta de amendoim": {"energy_kcal": 593, "protein_g": 27, "lipid_g": 46, "carbohydrate_g": 17, "fiber_g": 4},
    "iogurte grego": {"energy_kcal": 97, "protein_g": 9, "lipid_g": 5, "carbohydrate_g": 4, "fiber_g": 0},
    "iogurte parmalat fit": {"energy_kcal": 74, "protein_g": 10, "lipid_g": 0.9, "carbohydrate_g": 6.4, "fiber_g": 0},
    "parmalat fit": {"energy_kcal": 74, "protein_g": 10, "lipid_g": 0.9, "carbohydrate_g": 6.4, "fiber_g": 0},
    "tapioca": {"energy_kcal": 346, "protein_g": 0.5, "lipid_g": 0.1, "carbohydrate_g": 86, "fiber_g": 0},
    "granola": {"energy_kcal": 421, "protein_g": 10, "lipid_g": 12, "carbohydrate_g": 68, "fiber_g": 5},
    "cream cheese": {"energy_kcal": 342, "protein_g": 6, "lipid_g": 34, "carbohydrate_g": 4, "fiber_g": 0},
    "queijo cottage": {"energy_kcal": 98, "protein_g": 11, "lipid_g": 4, "carbohydrate_g": 3, "fiber_g": 0},
    "tilapia": {"energy_kcal": 128, "protein_g": 26, "lipid_g": 2.7, "carbohydrate_g": 0, "fiber_g": 0},
    "maionese heinz": {"energy_kcal": 629, "protein_g": 1, "lipid_g": 69, "carbohydrate_g": 2, "fiber_g": 0},
    "maionese": {"energy_kcal": 629, "protein_g": 1, "lipid_g": 69, "carbohydrate_g": 2, "fiber_g": 0},
    "nutella": {"energy_kcal": 540, "protein_g": 6, "lipid_g": 30, "carbohydrate_g": 57, "fiber_g": 5},
    "pastel carne": {"energy_kcal": 300, "protein_g": 12, "lipid_g": 18, "carbohydrate_g": 25, "fiber_g": 1},
    "pastel": {"energy_kcal": 300, "protein_g": 12, "lipid_g": 18, "carbohydrate_g": 25, "fiber_g": 1},
    "creatina": {"energy_kcal": 0, "protein_g": 0, "lipid_g": 0, "carbohydrate_g": 0, "fiber_g": 0},
    "cafeina": {"energy_kcal": 0, "protein_g": 0, "lipid_g": 0, "carbohydrate_g": 0, "fiber_g": 0},
    "bacon": {"energy_kcal": 540, "protein_g": 30, "lipid_g": 45, "carbohydrate_g": 2, "fiber_g": 0},
    "onion rings": {"energy_kcal": 420, "protein_g": 6, "lipid_g": 22, "carbohydrate_g": 50, "fiber_g": 3},
    "molho barbecue": {"energy_kcal": 180, "protein_g": 1, "lipid_g": 1, "carbohydrate_g": 45, "fiber_g": 1},
    "barbecue": {"energy_kcal": 180, "protein_g": 1, "lipid_g": 1, "carbohydrate_g": 45, "fiber_g": 1},
}


def load_taco():
    with open(TACO_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def normalize(text):
    """Remove acentos e lowercase para matching."""
    replacements = {
        "á": "a", "à": "a", "ã": "a", "â": "a",
        "é": "e", "ê": "e",
        "í": "i",
        "ó": "o", "ô": "o", "õ": "o",
        "ú": "u", "ü": "u",
        "ç": "c",
    }
    text = text.lower().strip()
    for k, v in replacements.items():
        text = text.replace(k, v)
    return text


def build_taco_index(taco_data):
    """Cria indice normalizado para busca exata na TACO."""
    index = {}
    for item in taco_data:
        key = normalize(item["description"])
        index[key] = item
    return index


def to_float(val):
    """Converte valor TACO para float (alguns campos sao string 'NA' ou 'Tr')."""
    if isinstance(val, (int, float)):
        return float(val)
    if isinstance(val, str):
        val = val.strip()
        if val in ("NA", "Tr", "*", "", "-"):
            return 0.0
        try:
            return float(val.replace(",", "."))
        except ValueError:
            return 0.0
    return 0.0


def find_in_taco(name, taco_index):
    """Busca deterministica: alias → TACO exato. Sem fuzzy."""
    name_norm = normalize(name)

    # 1. Match exato direto na TACO (nome completo)
    if name_norm in taco_index:
        return taco_index[name_norm], 1.0, "exact"

    # 2. Busca no ALIAS_MAP
    for alias, taco_desc in ALIAS_MAP.items():
        if normalize(alias) == name_norm:
            taco_norm = normalize(taco_desc)
            if taco_norm in taco_index:
                return taco_index[taco_norm], 1.0, f"alias:{alias}"
            break

    return None, 0.0, None


def calc_item(name, grams, taco_index):
    """Calcula macros para um item."""
    name_norm = normalize(name)

    # 1. Manual DB (industrializados)
    for key, vals in MANUAL_DB.items():
        if normalize(key) == name_norm:
            factor = grams / 100.0
            return {
                "name": name,
                "matched": f"[manual] {key}",
                "grams": grams,
                "confidence": 1.0,
                "kcal": round(vals["energy_kcal"] * factor),
                "protein_g": round(vals["protein_g"] * factor, 1),
                "fat_g": round(vals["lipid_g"] * factor, 1),
                "carbs_g": round(vals["carbohydrate_g"] * factor, 1),
                "fiber_g": round(vals["fiber_g"] * factor, 1),
                "source": "manual"
            }

    # 2. TACO (exato ou alias)
    match, score, method = find_in_taco(name, taco_index)
    if match:
        factor = grams / 100.0
        return {
            "name": name,
            "matched": match["description"],
            "grams": grams,
            "confidence": round(score, 2),
            "kcal": round(to_float(match["energy_kcal"]) * factor),
            "protein_g": round(to_float(match["protein_g"]) * factor, 1),
            "fat_g": round(to_float(match["lipid_g"]) * factor, 1),
            "carbs_g": round(to_float(match["carbohydrate_g"]) * factor, 1),
            "fiber_g": round(to_float(match.get("fiber_g", 0)) * factor, 1),
            "source": f"TACO ({method})"
        }

    # 3. Nao encontrou
    return {
        "name": name,
        "matched": None,
        "grams": grams,
        "confidence": 0.0,
        "kcal": 0, "protein_g": 0, "fat_g": 0, "carbs_g": 0, "fiber_g": 0,
        "source": "NOT_FOUND",
        "error": f"Alimento '{name}' nao encontrado. Use um alias conhecido ou descricao TACO exata."
    }


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: calc_macros.py '{\"items\": [...]}'"}, ensure_ascii=False))
        sys.exit(1)

    try:
        request = json.loads(sys.argv[1])
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"JSON invalido: {e}"}, ensure_ascii=False))
        sys.exit(1)

    items = request.get("items", [])
    if not items:
        print(json.dumps({"error": "Lista de items vazia"}, ensure_ascii=False))
        sys.exit(1)

    taco_data = load_taco()
    taco_index = build_taco_index(taco_data)

    results = []
    totals = {"kcal": 0, "protein_g": 0, "fat_g": 0, "carbs_g": 0, "fiber_g": 0}

    for item in items:
        name = item.get("name", "")
        grams = item.get("grams", 100)
        result = calc_item(name, grams, taco_index)
        results.append(result)
        totals["kcal"] += result["kcal"]
        totals["protein_g"] += result["protein_g"]
        totals["fat_g"] += result["fat_g"]
        totals["carbs_g"] += result["carbs_g"]
        totals["fiber_g"] += result["fiber_g"]

    totals["protein_g"] = round(totals["protein_g"], 1)
    totals["fat_g"] = round(totals["fat_g"], 1)
    totals["carbs_g"] = round(totals["carbs_g"], 1)
    totals["fiber_g"] = round(totals["fiber_g"], 1)

    output = {
        "items": results,
        "totals": totals,
        "items_count": len(results),
        "not_found": [r["name"] for r in results if r["source"] == "NOT_FOUND"]
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
