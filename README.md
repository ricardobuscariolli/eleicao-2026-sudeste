# Eleição 2026 no Sudeste: Lula x Flávio Bolsonaro por bairro e município

Mapas da margem de votos no **2º turno da eleição presidencial de 2026** (25/10/2026) nos quatro estados do Sudeste e nas suas capitais, feitos em R com dados abertos do TSE.

**Margem** = (Lula − Flávio) / (Lula + Flávio), em pontos percentuais. Vermelho indica vantagem de Lula, azul indica vantagem de Flávio, e quanto mais escuro, maior a vantagem. Votos brancos e nulos não entram no cálculo.

![São Paulo por distrito](mapas/capital_sao_paulo.png)

## O que tem aqui

| Recorte | Unidade | Mapa | Tabela |
|---|---|---|---|
| Sudeste | município | `mapas/sudeste_municipios.png` | `tabelas/tab_municipios_sudeste.csv` |
| SP, RJ, MG, ES | município | `mapas/estado_*.png` | `tabelas/tab_estados_sudeste.csv`, `tabelas/tab_regioes_sudeste.csv` |
| São Paulo (capital) | distrito (96) | `mapas/capital_sao_paulo.png` | `tabelas/tab_capital_sao_paulo.csv` |
| Rio de Janeiro | bairro | `mapas/capital_rio_de_janeiro.png` | `tabelas/tab_capital_rio_de_janeiro.csv` |
| Belo Horizonte | bairro | `mapas/capital_belo_horizonte.png` | `tabelas/tab_capital_belo_horizonte.csv` |
| Vitória | bairro | `mapas/capital_vitoria.png` | `tabelas/tab_capital_vitoria.csv` |

## Resultado por estado

| Estado | Margem | Municípios vencidos por Lula |
|---|---|---|
| Minas Gerais | Lula +0,9 | 527 de 853 |
| Rio de Janeiro | Flávio +6,2 | 18 de 92 |
| São Paulo | Flávio +7,7 | 72 de 645 |
| Espírito Santo | Flávio +12,7 | 17 de 78 |

## Como foi feito

1. **Votos:** votação por seção eleitoral do TSE (`votacao_secao_2026_BR`, cargo presidente, 2º turno).
2. **Localização:** cada seção é ligada às coordenadas do seu local de votação (`eleitorado_local_votacao_2026`, também do TSE).
3. **Agregação:** os locais de votação são somados dentro dos polígonos de bairros e distritos do IBGE (pacote [`geobr`](https://github.com/ipeaGIT/geobr)). Os mapas estaduais somam os votos diretamente por município.

## Como rodar

Você precisa do R (4.1 ou superior). Os pacotes `data.table`, `dplyr`, `sf`, `geobr`, `ggplot2` e `scales` são instalados automaticamente.

```r
setwd("pasta/onde/salvou")
source("mapas_eleicao_sudeste.R", encoding = "UTF-8")
```

Na primeira execução, o script baixa cerca de 400 MB do TSE (os arquivos descompactados ocupam alguns GB). Nas próximas, ele usa o cache em `dados_tse/`. Para outro estado ou outra capital, basta mudar `UFS` e a lista `capitais` no código.

## Limitações

- **O local de votação não é a residência do eleitor.** Ele aproxima onde a pessoa mora, mas não é a mesma coisa.
- **Bairros sem cor:** bairros sem nenhum local de votação dentro dos limites aparecem em cinza. Isso é comum em BH, que tem muitos bairros pequenos.
- **Divisões de 2010:** os bairros do IBGE são os do Censo 2010. A capital paulista não tem bairros oficiais, então usei os distritos.
- **Escala de cores:** a escala é cortada no percentil 98 da margem absoluta, para que poucos municípios extremos não desbotem o resto do mapa.

## Licença

Código sob licença MIT. Dados: TSE e IBGE (dados públicos).
