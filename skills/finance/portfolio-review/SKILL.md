# Skill: portfolio-review

Skill knowledge-based para revisao de carteira e planejamento tributario.
Sem scripts — usa dados do finai-db + conhecimento.

## Revisao de Carteira

### 1. Alocacao por Classe

Classes de ativo para portfolio brasileiro:

| Classe | Risco | Sugestao conservador-moderado |
|--------|-------|-------------------------------|
| Renda fixa pos (CDI) | Baixo | 30-40% |
| Renda fixa IPCA+ | Medio-baixo | 15-25% |
| Renda fixa pre | Medio | 5-10% |
| Acoes BR | Medio-alto | 15-25% |
| FIIs | Medio | 10-15% |
| Internacional | Medio-alto | 5-10% |
| Cripto | Alto | 0-5% |
| Reserva emergencia | Baixo | 6-12 meses despesas |

### 2. Drift Analysis

- Comparar alocacao ATUAL vs ALVO (definida em metas)
- Drift = |peso_atual - peso_alvo|
- Se drift > 5pp em qualquer classe → sugerir rebalanceamento
- Rebalancear por APORTE, nao por venda (evita IR)

### 3. Rebalanceamento por Aporte

Quando Doug fizer novo aporte:
1. Calcular alocacao atual
2. Identificar classe mais defasada
3. Direcionar 100% do aporte para a classe sub-alocada
4. Se necessario, dividir entre 2 classes mais defasadas

### 4. Projecao de Aposentadoria (simplificada)

Parametros:
- Patrimonio atual (net_worth)
- Aporte mensal
- Rendimento real estimado (IPCA + X%)
- Despesa mensal desejada na aposentadoria
- Regra dos 4% (ou 3% conservador para BR): patrimonio = despesa_anual / 0.04

Formula FV: FV = PV * (1+r)^n + PMT * ((1+r)^n - 1) / r

### 5. Tributacao BR — Guia Completo

#### Renda Fixa
| Prazo | Aliquota IR |
|-------|-------------|
| Ate 180 dias | 22,5% |
| 181 a 360 dias | 20,0% |
| 361 a 720 dias | 17,5% |
| Acima 720 dias | 15,0% |

**Isentos PF:** LCI, LCA, CRI, CRA, debentures incentivadas
**Come-cotas:** maio e novembro (fundos abertos, 15% sobre rendimento)
**IOF:** regressivo ate 30 dias (96% no dia 1, 0% no dia 30)

#### Acoes
- Swing trade: 15% sobre lucro (isento se vendas < R$20k/mes)
- Day trade: 20% sobre lucro (sem isencao)
- DARF ate ultimo dia util do mes seguinte
- Compensacao de prejuizo: mesmo tipo (swing com swing, day com day)

#### FIIs
- Rendimentos mensais: ISENTOS para PF
- Ganho de capital (venda): 20% (sem isencao de R$20k)
- DARF ate ultimo dia util do mes seguinte

#### Dividendos
- Isentos para PF (legislacao atual)
- JCP: 15% IRRF (retido na fonte)

#### Previdencia
- PGBL: deduz ate 12% renda tributavel no IR (tabela regressiva ou progressiva)
- VGBL: nao deduz, mas IR so sobre rendimentos
- Tabela regressiva: 35% (ate 2 anos) → 10% (acima 10 anos)

### 6. Checklist de Revisao Periodica

**Mensal:**
- [ ] Alocacao atual vs alvo
- [ ] Rendimentos recebidos (dividendos, JCP, cupons)
- [ ] DARFs a pagar

**Trimestral:**
- [ ] Performance vs CDI
- [ ] Rebalanceamento necessario?
- [ ] Novas oportunidades (SELIC mudou? IPCA mudou?)

**Anual:**
- [ ] Revisao de alocacao alvo
- [ ] Declaracao IR (informe de rendimentos)
- [ ] Come-cotas impacto
- [ ] Projecao de aposentadoria atualizada

## Regras

1. Sempre considere impacto tributario antes de sugerir movimentacoes
2. Prefira rebalanceamento por aporte (sem trigger de IR)
3. Considere liquidez — nao travar tudo em longo prazo
4. Reserva de emergencia = sagrada (6-12 meses, liquidez D+0)
5. Diversificacao entre instituicoes (FGC = R$250k por CPF/instituicao)
6. Custos importam: taxa de administracao, corretagem, spread
