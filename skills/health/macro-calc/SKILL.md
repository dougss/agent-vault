---
name: macro-calc
description: Calcula macronutrientes de alimentos usando a Tabela TACO (UNICAMP) com 597 alimentos brasileiros
metadata:
  openclaw:
    requires:
      bins: [python3]
---

# Macro Calculator (TACO + USDA)

Calcula macronutrientes precisos a partir de descricoes em linguagem natural.

## Fonte de dados

- **Primaria:** Tabela TACO 4a edicao (UNICAMP) — 597 alimentos brasileiros, dados laboratoriais
- **Fallback:** USDA FoodData Central API (gratis, 300K+ alimentos)
- Valores sao por 100g na TACO. O script calcula pelo peso informado.

## Como usar

Quando o usuario informar uma refeicao em linguagem natural, voce deve:

1. **Parsear** o input em itens estruturados. Extraia:
   - Nome do alimento (use o nome mais proximo da TACO)
   - Quantidade em gramas (converta porcoes caseiras usando a tabela abaixo)
   - Tipo de refeicao (cafe, almoco, lanche, jantar, ceia)

2. **Chamar o script** para cada item:
```bash
python3 ~/.openclaw/workspaces/health-coach/skills/macro-calc/scripts/calc_macros.py '{"items": [{"name": "ovo, de galinha, inteiro, cozido", "grams": 200}, {"name": "pão, trigo, forma, integral", "grams": 50}]}'
```

3. **Apresentar** os resultados em formato tabular e registrar na memoria.

## Tabela de Porcoes Caseiras (referencia para parsing)

Use esta tabela para converter porcoes do usuario em gramas:

| Porcao | Alimento | Peso (g) |
|--------|----------|----------|
| 1 fatia | pao de forma | 25 |
| 1 fatia | pao frances | 50 |
| 1 unidade | ovo grande | 50 |
| 1 unidade | banana media | 86 |
| 1 unidade | maca media | 130 |
| 1 colher sopa | arroz | 25 |
| 1 escumadeira | arroz | 75 |
| 1 concha media | feijao | 86 |
| 1 colher sopa | aveia | 15 |
| 1 colher sopa | azeite | 8 |
| 1 colher sopa | pasta amendoim | 16 |
| 1 colher sopa | requeijao | 15 |
| 1 file medio | frango (peito) | 120 |
| 1 bife medio | carne (patinho) | 100 |
| 1 posta media | peixe | 120 |
| 1 lata | atum | 120 (drenado 84) |
| 1 scoop | whey protein | 30 |
| 1 copo | leite | 200 |
| 1 pote | iogurte grego | 170 |
| 1 porcao | tapioca (goma) | 50 |
| 100g | arroz cozido | 100 |
| 100g | frango grelhado | 100 |

## Alimentos NAO presentes na TACO (usar valores fixos)

Estes sao industrializados que nao constam na tabela. Use os valores abaixo diretamente:

| Alimento | Por 100g | Kcal | P(g) | G(g) | C(g) |
|----------|----------|------|------|------|------|
| Whey protein (concentrado) | 100g | 375 | 80 | 4 | 8 |
| Requeijao cremoso | 100g | 257 | 7 | 24 | 3 |
| Pasta de amendoim integral | 100g | 593 | 27 | 46 | 17 |
| Iogurte grego natural | 100g | 97 | 9 | 5 | 4 |
| Tapioca (goma hidratada) | 100g | 346 | 0.5 | 0.1 | 86 |
| Granola | 100g | 421 | 10 | 12 | 68 |
| Cream cheese | 100g | 342 | 6 | 34 | 4 |
| Queijo cottage | 100g | 98 | 11 | 4 | 3 |
| Maionese Heinz | 100g | 629 | 1 | 69 | 2 |

## Formato de saida esperado

Ao apresentar o calculo, use este formato:

```
[refeicao] registrada:

| Item | Qtd | Kcal | P | G | C |
|------|-----|------|---|---|---|
| ... | ... | ... | ... | ... | ... |
| TOTAL | | ... | ... | ... | ... |

Acumulado hoje: X/TARGET kcal (Y%) | Xg/TARGET prot (Y%)
```

## Notas

- Sempre use a versao COZIDA quando disponivel (ex: "arroz, tipo 1, cozido" e nao "cru")
- Se o usuario nao especificar preparo, assuma cozido/grelhado (nao frito)
- Para carnes, use a versao "sem gordura" quando o usuario nao especificar
- Arredonde valores para inteiros na apresentacao
- Mantenha o acumulado do dia na memoria da sessao
