# =============================================================================
# Eleição presidencial 2026 (2º turno): margem Lula x Flávio Bolsonaro no Sudeste
#
#   - Sudeste e cada estado (SP, RJ, MG, ES) por município
#   - Capitais: São Paulo (distritos), Rio, Belo Horizonte e Vitória (bairros)
#
# Margem = 100 * (Lula - Flávio) / (Lula + Flávio), em pontos percentuais
#   > 0 vermelho (Lula)  |  < 0 azul (Flávio)
#
# Dados: TSE (votação por seção + coordenadas dos locais de votação)
# Malhas: IBGE, via pacote geobr
#
# Como rodar: defina a pasta de trabalho e use source(), por exemplo
#   setwd("C:/mapas_eleicao")
#   source("mapas_eleicao_sudeste.R", encoding = "UTF-8")
# Na primeira execução, o script baixa ~400 MB do TSE para a subpasta dados_tse/.
# Os resultados ficam em mapas/ (PNG) e tabelas/ (CSV).
# =============================================================================

dir.create("dados_tse", showWarnings = FALSE)
dir.create("mapas", showWarnings = FALSE)
dir.create("tabelas", showWarnings = FALSE)

pkgs <- c("data.table", "dplyr", "sf", "geobr", "ggplot2", "scales")
novos <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(novos)) install.packages(novos)
invisible(lapply(pkgs, library, character.only = TRUE))
sf::sf_use_s2(FALSE)
options(timeout = 7200)

ANO       <- 2026
TURNO     <- 2
NR_LULA   <- 13
NR_FLAVIO <- 22
UFS       <- c("SP", "RJ", "MG", "ES")
NOME_UF   <- c(SP = "São Paulo", RJ = "Rio de Janeiro", MG = "Minas Gerais", ES = "Espírito Santo")

# ---- Utilitários -----------------------------------------------------------------
baixar_tse <- function(url) {
  zip <- file.path("dados_tse", basename(url))
  if (!file.exists(zip)) {
    message("  Baixando ", basename(url), " (pode demorar)...")
    ok <- tryCatch({ download.file(url, zip, mode = "wb"); TRUE },
                   error = function(e) FALSE, warning = function(w) FALSE)
    if (!ok) { if (file.exists(zip)) file.remove(zip); stop("Falha ao baixar: ", url) }
  }
  conteudo <- unzip(zip, list = TRUE)$Name
  destino  <- file.path("dados_tse", conteudo)
  if (!all(file.exists(destino))) unzip(zip, exdir = "dados_tse")
  destino
}
limpar_cache_geobr <- function() {
  unlink(list.files(tempdir(), pattern = "\\.(gpkg|zip|parquet)$",
                    full.names = TRUE, recursive = TRUE))
  unlink(tools::R_user_dir("geobr", "cache"), recursive = TRUE)
}
ler_geobr <- function(f, ...) {
  for (i in 1:3) {
    x <- tryCatch(suppressMessages(f(..., showProgress = FALSE)), error = function(e) NULL)
    if (!is.null(x) && nrow(x) > 0) return(x)
    message("  geobr falhou (tentativa ", i, "), tentando de novo...")
    limpar_cache_geobr()
  }
  NULL
}
num  <- function(x) as.numeric(gsub(",", ".", x))
slug <- function(x) gsub("[^a-z0-9]+", "_", tolower(iconv(x, to = "ASCII//TRANSLIT")))

# ---- 1. Votos para presidente (arquivo nacional _BR) -----------------------------
message("Votos para presidente...")
url_pres <- sprintf("https://cdn.tse.jus.br/estatistica/sead/odsele/votacao_secao/votacao_secao_%d_BR.zip", ANO)
arqs <- baixar_tse(url_pres)
csv  <- grep("_BR\\.csv$", arqs, value = TRUE)[1]
if (is.na(csv)) csv <- grep("\\.csv$", arqs, value = TRUE)[1]
pres <- fread(csv, sep = ";", encoding = "Latin-1",
              select = c("NR_TURNO", "SG_UF", "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO",
                         "CD_CARGO", "NR_VOTAVEL", "QT_VOTOS"))
pres <- pres[SG_UF %in% UFS & CD_CARGO == 1 & NR_VOTAVEL %in% c(NR_LULA, NR_FLAVIO)]
if (!TURNO %in% pres$NR_TURNO) { message(">>> 2º turno indisponível; usando 1º."); TURNO <- 1 }
pres <- pres[NR_TURNO == TURNO]
pres[, cand := fifelse(NR_VOTAVEL == NR_LULA, "lula", "flavio")]
votos <- dcast(pres, SG_UF + CD_MUNICIPIO + NR_ZONA + NR_SECAO ~ cand,
               value.var = "QT_VOTOS", fun.aggregate = sum, fill = 0)
votos[, CD_MUNICIPIO := as.integer(CD_MUNICIPIO)]
rm(pres); invisible(gc())
message(">>> Eleição: ", ANO, ", ", TURNO, "º turno")

# ---- 2. Correspondência TSE <-> IBGE -----------------------------------------------
de_para <- fread("https://raw.githubusercontent.com/betafcc/Municipios-Brasileiros-TSE/master/municipios_brasileiros_tse.csv")
de_para <- de_para[, .(CD_MUNICIPIO = as.integer(codigo_tse), code_muni = as.numeric(codigo_ibge))]
tse_de  <- function(ibge) de_para[code_muni == ibge, CD_MUNICIPIO][1]

# ---- 3. Coordenadas dos locais de votação --------------------------------------------
message("Locais de votação...")
url_loc <- sprintf("https://cdn.tse.jus.br/estatistica/sead/odsele/eleitorado_locais_votacao/eleitorado_local_votacao_%d.zip", ANO)
arqs_loc <- baixar_tse(url_loc)
csv_loc  <- grep(paste0("_(", paste(UFS, collapse = "|"), ")\\.csv$"), arqs_loc, value = TRUE)
locais <- rbindlist(lapply(csv_loc, fread, sep = ";", encoding = "Latin-1",
                           select = c("NR_TURNO", "SG_UF", "CD_MUNICIPIO", "NR_ZONA",
                                      "NR_SECAO", "NR_LATITUDE", "NR_LONGITUDE")))
if (TURNO %in% locais$NR_TURNO) locais <- locais[NR_TURNO == TURNO]
locais <- locais[, .(SG_UF, CD_MUNICIPIO = as.integer(CD_MUNICIPIO), NR_ZONA, NR_SECAO,
                     lat = num(NR_LATITUDE), lon = num(NR_LONGITUDE))]
locais <- unique(locais, by = c("SG_UF", "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO"))
locais <- locais[!is.na(lat) & lat != -1 & lon != -1]

votos_em_pontos <- function(cd_mun) {
  vm <- votos[CD_MUNICIPIO == cd_mun]
  v  <- merge(vm, locais, by = c("SG_UF", "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO"))
  message(sprintf("  Votos com coordenada: %.1f%%",
                  100 * sum(v$lula + v$flavio) / sum(vm$lula + vm$flavio)))
  v <- v[, .(lula = sum(lula), flavio = sum(flavio)), by = .(lat, lon)]
  st_as_sf(v, coords = c("lon", "lat"), crs = 4674)
}
agregar <- function(pontos, poligonos) {
  poligonos <- st_transform(poligonos, 4674) |>
    group_by(nome) |> summarise(.groups = "drop")          # une polígonos de mesmo nome
  tot <- st_join(pontos, poligonos["nome"], join = st_within) |>
    st_drop_geometry() |> filter(!is.na(nome)) |>
    group_by(nome) |> summarise(lula = sum(lula), flavio = sum(flavio), .groups = "drop")
  poligonos |> left_join(tot, by = "nome") |>
    mutate(margem = 100 * (lula - flavio) / (lula + flavio))
}

# ---- 4. Função do mapa (formato ajustado à área; escala robusta) -----------------
fazer_mapa <- function(dados, titulo, arquivo, rotulos = NULL, tam_txt = 2,
                       contornos = NULL) {
  lim <- ceiling(quantile(abs(dados$margem), 0.98, na.rm = TRUE) / 5) * 5
  bb  <- st_bbox(dados)
  asp <- as.numeric((bb$ymax - bb$ymin) / ((bb$xmax - bb$xmin) * cos(mean(c(bb$ymin, bb$ymax)) * pi / 180)))
  larg <- 11
  alt  <- min(max(larg * 0.85 * asp + 1.6, 6), 13)
  g <- ggplot(dados) +
    geom_sf(aes(fill = margem), color = "white", linewidth = 0.06) +
    scale_fill_gradient2(low = "#08306B", mid = "#F7F7F7", high = "#67000D", midpoint = 0,
                         limits = c(-lim, lim), oob = scales::squish,
                         labels = function(x) ifelse(x > 0, paste0("Lula +", x),
                                         ifelse(x < 0, paste0("Flávio +", abs(x)), "Empate")),
                         name = "Margem (p.p.)", na.value = "grey85") +
    labs(title = titulo,
         subtitle = sprintf("Presidente, %dº turno %d — margem entre os votos dos dois candidatos", TURNO, ANO),
         caption = "Fonte: TSE (votação por seção e locais de votação); malhas IBGE via geobr") +
    theme_void(base_size = 12) +
    theme(plot.title = element_text(face = "bold", size = 16),
          plot.background = element_rect(fill = "white", color = NA),
          plot.margin = margin(10, 10, 10, 10))
  if (!is.null(contornos))
    g <- g + geom_sf(data = contornos, fill = NA, color = "grey20", linewidth = 0.5)
  if (!is.null(rotulos) && nrow(rotulos) > 0)
    g <- g + geom_sf_text(data = rotulos, aes(label = nome), size = tam_txt,
                          check_overlap = TRUE, color = "grey10", fontface = "bold",
                          fun.geometry = sf::st_point_on_surface)
  ggsave(file.path("mapas", arquivo), g, width = larg, height = alt, dpi = 150)
  message("  Salvo: mapas/", arquivo)
  invisible(g)
}
# rótulos: maiores em votos + extremos de cada lado
escolher_rotulos <- function(d, n_maiores = 20, n_extremos = 4) {
  d <- d |> filter(!is.na(margem))
  if (nrow(d) <= n_maiores + 2 * n_extremos) return(d)
  sel <- unique(c(head(d$nome[order(-(d$lula + d$flavio))], n_maiores),
                  head(d$nome[order(d$margem)], n_extremos),
                  head(d$nome[order(-d$margem)], n_extremos)))
  d |> filter(nome %in% sel)
}
tabela <- function(x) x |> st_drop_geometry() |>
  transmute(nome, lula, flavio, total = lula + flavio, margem_pp = round(margem, 1)) |>
  arrange(desc(margem_pp))

# ---- 5. Capitais ---------------------------------------------------------------------
bairros_br <- NULL
capitais <- list(
  list(nome = "São Paulo",      ibge = 3550308, tipo = "distrito", n = Inf, txt = 2.0),
  list(nome = "Rio de Janeiro", ibge = 3304557, tipo = "bairro",   n = 26,  txt = 2.6),
  list(nome = "Belo Horizonte", ibge = 3106200, tipo = "bairro",   n = 26,  txt = 2.6),
  list(nome = "Vitória",        ibge = 3205309, tipo = "bairro",   n = 30,  txt = 2.6)
)
for (cap in capitais) {
  message("Capital: ", cap$nome, "...")
  if (cap$tipo == "distrito") {
    setores <- NULL
    for (a in c(2010, 2020, 2019, 2017)) {
      setores <- ler_geobr(read_census_tract, code_tract = cap$ibge, year = a, simplified = TRUE)
      if (!is.null(setores) && "name_district" %in% names(setores)) break
    }
    if (is.null(setores)) { message("  Sem setores; pulando."); next }
    pol <- setores |> transmute(nome = name_district)
  } else {
    if (is.null(bairros_br)) bairros_br <- ler_geobr(read_neighborhood, year = 2010, simplified = TRUE)
    if (is.null(bairros_br)) { message("  Sem bairros; pulando."); next }
    pol <- bairros_br |> filter(code_muni == cap$ibge) |> transmute(nome = name_neighborhood)
    if (nrow(pol) == 0) { message("  IBGE não tem bairros para ", cap$nome, "; pulando."); next }
  }
  d <- agregar(votos_em_pontos(tse_de(cap$ibge)), pol)
  rot <- if (is.infinite(cap$n)) d else escolher_rotulos(d, cap$n)
  rotulo_tipo <- if (cap$tipo == "distrito") "distritos" else "bairros"
  fazer_mapa(d, paste0("Lula x Flávio Bolsonaro — ", cap$nome, " (", rotulo_tipo, ")"),
             paste0("capital_", slug(cap$nome), ".png"), rotulos = rot, tam_txt = cap$txt)
  fwrite(tabela(d), file.path("tabelas", paste0("tab_capital_", slug(cap$nome), ".csv")))
}

# ---- 6. Estados e Sudeste por município ------------------------------------------
message("Municípios do Sudeste...")
muns <- do.call(rbind, lapply(UFS, function(u)
  ler_geobr(read_municipality, code_muni = u, year = 2020, simplified = TRUE)))
ufs_geo <- do.call(rbind, lapply(UFS, function(u)
  ler_geobr(read_state, code_state = u, year = 2020, simplified = TRUE)))
regs <- do.call(rbind, lapply(UFS, function(u)
  ler_geobr(read_intermediate_region, code_intermediate = u, year = 2019)))

# Remove as ilhas oceânicas (Trindade e Martim Vaz, município de Vitória),
# que ficam a ~1.100 km da costa e esticam o mapa
caixa   <- st_bbox(c(xmin = -54, xmax = -38.5, ymin = -26, ymax = -14), crs = st_crs(muns))
muns    <- suppressWarnings(st_crop(muns, caixa))
ufs_geo <- suppressWarnings(st_crop(ufs_geo, caixa))

por_mun <- merge(votos[, .(lula = sum(lula), flavio = sum(flavio)), by = CD_MUNICIPIO],
                 de_para, by = "CD_MUNICIPIO")
mun <- muns |> left_join(por_mun, by = "code_muni") |>
  mutate(nome = name_muni, margem = 100 * (lula - flavio) / (lula + flavio))

# região intermediária de cada município
pts <- st_point_on_surface(mun)
if (!is.null(regs)) {
  pts <- st_join(pts, st_transform(regs["name_intermediate"], st_crs(pts)))
} else pts$name_intermediate <- NA_character_
tab_mun <- pts |> st_drop_geometry() |>
  transmute(uf = abbrev_state, municipio = nome, regiao = name_intermediate,
            lula, flavio, total = lula + flavio, margem_pp = round(margem, 1)) |>
  arrange(desc(margem_pp))
fwrite(tab_mun, file.path("tabelas", "tab_municipios_sudeste.csv"))

resumir <- function(d, ...) d |> group_by(...) |>
  summarise(lula = sum(lula, na.rm = TRUE), flavio = sum(flavio, na.rm = TRUE), .groups = "drop") |>
  mutate(total = lula + flavio, margem_pp = round(100 * (lula - flavio) / total, 1),
         munic_lula = NA) |> arrange(desc(margem_pp))
tab_uf  <- resumir(tab_mun, uf)
tab_uf$munic_lula <- sapply(tab_uf$uf, function(u) sum(tab_mun$margem_pp[tab_mun$uf == u] > 0, na.rm = TRUE))
tab_reg <- resumir(tab_mun, uf, regiao) |> select(-munic_lula)
fwrite(tab_uf,  file.path("tabelas", "tab_estados_sudeste.csv"))
fwrite(tab_reg, file.path("tabelas", "tab_regioes_sudeste.csv"))

# Mapa do Sudeste: rótulos só nas capitais
caps_nomes <- c("São Paulo", "Rio de Janeiro", "Belo Horizonte", "Vitória")
rot_sud <- mun |> filter(nome %in% caps_nomes, code_muni %in% c(3550308, 3304557, 3106200, 3205309))
fazer_mapa(mun, "Lula x Flávio Bolsonaro — Sudeste (municípios)", "sudeste_municipios.png",
           rotulos = rot_sud, tam_txt = 3, contornos = ufs_geo)

# Um mapa por estado
for (u in UFS) {
  d <- mun |> filter(abbrev_state == u)
  rot <- d |> slice_max(lula + flavio, n = 12)
  fazer_mapa(d, paste0("Lula x Flávio Bolsonaro — ", NOME_UF[u], " (municípios)"),
             paste0("estado_", tolower(u), ".png"), rotulos = rot, tam_txt = 2.6)
}

writeLines(sprintf("ANO=%d TURNO=%d", ANO, TURNO), "info_rodada.txt")
message("\n>>> Resumo por estado:")
print(tab_uf)
message("Pronto! Mapas em: ", normalizePath("mapas"), " | Tabelas em: ", normalizePath("tabelas"))
if (.Platform$OS.type == "windows") shell.exec(normalizePath("mapas"))
