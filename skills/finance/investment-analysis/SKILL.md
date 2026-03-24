# Skill: investment-analysis

Skill knowledge-based para analise fundamentalista de ativos financeiros.
Sem scripts — usa seu conhecimento + web search para dados atualizados.

## Frameworks de Analise

### 1. Analise Comparativa (Comps)

Compare o ativo com pares do setor usando multiplos:

| Multiplo | O que mede | Bom sinal |
|----------|-----------|-----------|
| P/L | Preco / Lucro | Abaixo da media do setor |
| P/VP | Preco / Valor Patrimonial | < 1.0 pode indicar desconto |
| EV/EBITDA | Enterprise Value / EBITDA | Menor que pares |
| P/Receita | Preco / Receita | Util para empresas em crescimento |
| Dividend Yield | Dividendo / Preco | > SELIC = atrativo para renda |
| Payout | % lucro distribuido | 25-75% saudavel |

### 2. Qualidade do Negocio

| Metrica | O que mede | Referencia |
|---------|-----------|------------|
| ROE | Retorno sobre PL | > 15% bom |
| ROIC | Retorno sobre capital investido | > WACC |
| Margem liquida | Lucro / Receita | Estavel ou crescente |
| Divida/EBITDA | Alavancagem | < 2.5x conservador |
| Crescimento receita | CAGR 5 anos | > inflacao |
| FCF Yield | Free Cash Flow / Market Cap | > 5% atrativo |

### 3. Screening por Perfil

**Value (conservador — perfil do Doug):**
- P/L < 10, P/VP < 1.5, Dividend Yield > 5%
- Divida/EBITDA < 2.0, ROE > 12%
- Historico de dividendos consistente (5+ anos)

**Growth:**
- CAGR receita > 15%, margem crescente
- ROE > 20%, reinvestimento alto (payout < 40%)

**Quality:**
- ROE > 20%, ROIC > 15%, margem liquida > 15%
- Divida baixa, FCF positivo consistente

### 4. DCF Simplificado

Para estimativa de valor justo:
1. Projetar FCF 5 anos (usar CAGR historico como base)
2. Terminal value: FCF ano 5 * (1 + g) / (WACC - g)
   - g = crescimento perpetuo (3-4% para BR)
   - WACC = custo de capital (tipicamente 12-15% para acoes BR)
3. Trazer a valor presente
4. Dividir por numero de acoes
5. Margem de seguranca: 20-30% de desconto

### 5. Analise de FIIs

| Metrica | Referencia |
|---------|------------|
| P/VP | < 1.0 = desconto |
| Dividend Yield | > CDI liquido = atrativo |
| Vacancia | < 5% tijolo, N/A papel |
| Cap Rate | > 8% |
| Liquidez | Volume diario > R$500k |

Tipos: tijolo (lajes, logistica, shopping), papel (CRI), hibrido, FOF
Tributacao: rendimentos isentos PF, 20% sobre ganho capital

### 6. Analise de Earnings

Ao analisar resultados trimestrais:
1. Receita vs estimativa de mercado
2. EBITDA e margens vs trimestre anterior e mesmo trimestre ano anterior
3. Guidance atualizado
4. Eventos nao recorrentes
5. Endividamento: mudanca no perfil de divida
6. Capex: manutencao vs crescimento

## Fontes de Dados (web search)

- **StatusInvest:** statusinvest.com.br — multiplos, historico dividendos, DRE
- **Fundamentus:** fundamentus.com.br — screening, indicadores
- **RI das empresas:** ri.empresa.com.br — releases, apresentacoes
- **B3:** b3.com.br — dados oficiais
- **Tesouro Direto:** tesourodireto.com.br — taxas renda fixa

## Regras

1. NUNCA diga "compre" ou "venda" — apresente analise e cenarios
2. Sempre mencione riscos relevantes (setor, macro, regulatorio)
3. Compare com alternativas (custo de oportunidade vs CDI)
4. Contextualize para realidade do Doug (conservador-moderado, longo prazo)
5. Dados podem estar desatualizados — sempre mencione a data de referencia
6. Para cotacoes atuais, use web search
