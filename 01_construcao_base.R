# ============================================================
# PROJETO: DINÂMICAS DO DESMATAMENTO NO PARÁ
# SCRIPT 01 - CONSTRUÇÃO DA BASE MUNICIPAL
# Base: 2008-2025 | Unidade de análise: município-ano
# ============================================================
#
# Objetivo:
# Construir uma base municipal anual a partir dos polígonos PRODES
# e da malha municipal do IBGE.
#
# Procedimentos:
# 1. Seleção dos dados do Pará;
# 2. transformação para projeção equivalente EPSG:6933;
# 3. correção e preparação das geometrias;
# 4. identificação dos polígonos que intersectam o limite estadual;
# 5. interseção dos polígonos com os municípios;
# 6. alocação proporcional do atributo area_km;
# 7. agregação por município e ano;
# 8. construção do painel completo de 144 municípios x 18 anos.
#
# Antes de executar:
# - Coloque os arquivos de entrada na pasta indicada em diretorio_dados;
# - confira os nomes dos arquivos;
# - execute o script a partir da pasta do projeto.
#
# A correspondência Município-RI será incorporada no Script 02.
# As verificações exploratórias detalhadas ficam no script de auditoria.
# ============================================================


# 0. PACOTES --------------------------------------------------

pacotes <- c("sf", "dplyr", "tidyr", "tibble", "readr")

faltantes <- pacotes[
  !vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)
]

if (length(faltantes) > 0) {
  stop(
    "Instale os pacotes: ",
    paste(faltantes, collapse = ", ")
  )
}

library(sf)
library(dplyr)
library(tidyr)
library(tibble)
library(readr)


# 1. CAMINHOS -------------------------------------------------

# Altere "." se os arquivos estiverem em outra pasta.
diretorio_dados <- "."

arquivo_desmatamento <- file.path(
  diretorio_dados,
  "yearly_deforestation_biome_amazonia_v20260616.shp"
)

arquivo_municipios <- file.path(
  diretorio_dados,
  "BR_Municipios_2023.shp"
)

arquivo_uf <- file.path(
  diretorio_dados,
  "BR_UF_2023.shp"
)

diretorio_saida <- "resultados"
if (!dir.exists(diretorio_saida)) {
  dir.create(diretorio_saida, recursive = TRUE)
}

arquivos <- c(
  arquivo_desmatamento,
  arquivo_municipios,
  arquivo_uf
)

if (!all(file.exists(arquivos))) {
  stop(
    "Um ou mais arquivos de entrada não foram encontrados. ",
    "Confira diretorio_dados e os nomes dos arquivos."
  )
}


# 2. LEITURA E SELEÇÃO DOS DADOS -------------------------------

message("Lendo os arquivos de entrada...")

desmatamento <- st_read(arquivo_desmatamento, quiet = FALSE)
municipios <- st_read(arquivo_municipios, quiet = FALSE)
ufs <- st_read(arquivo_uf, quiet = FALSE)

# Seleção do Pará nas três camadas
desmat_pa <- desmatamento %>%
  filter(state == "PA")

mun_pa <- municipios %>%
  filter(NM_UF == "Pará")

pa_ibge <- ufs %>%
  filter(SIGLA_UF == "PA")

# Verificações dos campos necessários
campos_prodes <- c("fid", "year", "area_km", "state")
campos_municipios <- c("CD_MUN", "NM_MUN", "NM_UF", "AREA_KM2")

if (!all(campos_prodes %in% names(desmat_pa))) {
  stop("A camada PRODES não contém todos os campos esperados.")
}

if (!all(campos_municipios %in% names(mun_pa))) {
  stop("A malha municipal não contém todos os campos esperados.")
}

if (anyDuplicated(mun_pa$CD_MUN) > 0) {
  stop("Foram encontrados códigos municipais duplicados.")
}

if (nrow(mun_pa) != 144) {
  warning(
    "A malha selecionada contém ", nrow(mun_pa),
    " municípios; confira se corresponde à versão utilizada na pesquisa."
  )
}


# 3. PROJEÇÃO E PREPARAÇÃO DAS GEOMETRIAS ----------------------

# EPSG:6933: projeção equivalente utilizada nos cálculos de área.
crs_analise <- 6933

message("Transformando as camadas para EPSG:6933...")

desmat_pa_eq <- st_transform(desmat_pa, crs_analise)
mun_pa_eq <- st_transform(mun_pa, crs_analise)
pa_ibge_eq <- st_transform(pa_ibge, crs_analise)

# Corrigir geometrias inválidas
if (any(!st_is_valid(desmat_pa_eq), na.rm = TRUE)) {
  desmat_pa_eq <- st_make_valid(desmat_pa_eq)
}

if (any(!st_is_valid(mun_pa_eq), na.rm = TRUE)) {
  mun_pa_eq <- st_make_valid(mun_pa_eq)
}

if (any(!st_is_valid(pa_ibge_eq), na.rm = TRUE)) {
  pa_ibge_eq <- st_make_valid(pa_ibge_eq)
}

# Tratar GeometryCollection identificadas na camada PRODES:
# extrair componentes poligonais, unir por fid e recuperar atributos.
tipos <- as.character(st_geometry_type(desmat_pa_eq))
ids_colecao <- which(tipos == "GEOMETRYCOLLECTION")

if (length(ids_colecao) > 0) {

  colecoes <- desmat_pa_eq[ids_colecao, ]

  colecoes_poligonais <- st_collection_extract(
    colecoes,
    type = "POLYGON",
    warn = FALSE
  )

  colecoes_unidas <- colecoes_poligonais %>%
    group_by(fid) %>%
    summarise(do_union = TRUE, .groups = "drop")

  atributos_colecoes <- colecoes %>%
    st_drop_geometry()

  colecoes_unidas <- colecoes_unidas %>%
    left_join(atributos_colecoes, by = "fid") %>%
    st_as_sf()

  desmat_sem_colecoes <- desmat_pa_eq %>%
    filter(!fid %in% colecoes$fid)

  desmat_pa_eq <- bind_rows(
    desmat_sem_colecoes,
    colecoes_unidas
  ) %>%
    arrange(fid)
}

# Conferências impeditivas antes das operações espaciais
if (any(st_is_empty(desmat_pa_eq))) {
  stop("Há geometrias vazias na camada PRODES preparada.")
}

if (any(!st_is_valid(desmat_pa_eq))) {
  stop("Persistem geometrias inválidas na camada PRODES preparada.")
}

if (any(st_is_empty(mun_pa_eq)) || any(!st_is_valid(mun_pa_eq))) {
  stop("A camada municipal contém geometrias vazias ou inválidas.")
}

if (anyDuplicated(desmat_pa_eq$fid) > 0) {
  stop("Há fid duplicado após o tratamento das geometrias.")
}


# 4. IDENTIFICAÇÃO DOS POLÍGONOS QUE INTERSECTAM O PARÁ ---------

message("Identificando os polígonos que intersectam o limite estadual...")

intersecta_pa <- lengths(
  st_intersects(desmat_pa_eq, pa_ibge_eq)
) > 0

desmat_intersecta_pa <- desmat_pa_eq %>%
  mutate(intersecta_pa = intersecta_pa) %>%
  filter(intersecta_pa)

# Calcular a proporção da geometria de cada polígono situada no Pará.
# O atributo area_km do PRODES será posteriormente distribuído
# segundo essa proporção geométrica, implicitamente na interseção
# com os limites municipais.

intersecao_pa <- st_intersection(
  desmat_intersecta_pa,
  pa_ibge_eq %>% select(SIGLA_UF)
)

areas_originais_pa <- desmat_intersecta_pa %>%
  mutate(
    area_geometrica_original =
      as.numeric(st_area(geometry)) / 1e6
  ) %>%
  st_drop_geometry() %>%
  select(fid, area_km, area_geometrica_original)

areas_intersecao_pa <- intersecao_pa %>%
  mutate(
    area_geometrica_pa =
      as.numeric(st_area(geometry)) / 1e6
  ) %>%
  st_drop_geometry() %>%
  group_by(fid) %>%
  summarise(
    area_geometrica_pa = sum(area_geometrica_pa, na.rm = TRUE),
    .groups = "drop"
  )

areas_pa <- areas_originais_pa %>%
  left_join(areas_intersecao_pa, by = "fid") %>%
  mutate(
    area_geometrica_pa = coalesce(area_geometrica_pa, 0),
    proporcao_pa = if_else(
      area_geometrica_original > 0,
      area_geometrica_pa / area_geometrica_original,
      0
    ),
    proporcao_pa = pmin(pmax(proporcao_pa, 0), 1),
    area_prodes_pa = area_km * proporcao_pa
  )

resumo_area_pa <- areas_pa %>%
  summarise(
    n_poligonos = n(),
    area_prodes_atribuida_pa = sum(area_prodes_pa, na.rm = TRUE),
    proporcao_minima = min(proporcao_pa, na.rm = TRUE),
    proporcao_maxima = max(proporcao_pa, na.rm = TRUE)
  )

print(resumo_area_pa)


# 5. INTERSEÇÃO COM OS MUNICÍPIOS E ALOCAÇÃO PROPORCIONAL ------

message("Intersectando os polígonos PRODES com os municípios...")

intersecao_municipal <- st_intersection(
  desmat_intersecta_pa,
  mun_pa_eq %>%
    select(CD_MUN, NM_MUN, NM_RGINT, AREA_KM2)
)

# Área geométrica de cada fragmento resultante da interseção
intersecao_municipal <- intersecao_municipal %>%
  mutate(
    area_geometrica_fragmento =
      as.numeric(st_area(geometry)) / 1e6
  )

# Área geométrica original do polígono PRODES antes da divisão
area_original_poligonos <- desmat_intersecta_pa %>%
  mutate(
    area_geometrica_original =
      as.numeric(st_area(geometry)) / 1e6
  ) %>%
  st_drop_geometry() %>%
  select(fid, area_km, area_geometrica_original)

# Associar a área original aos fragmentos municipais.
# Como area_km já existe na interseção, o atributo original recebe
# o sufixo _original.
intersecao_municipal <- intersecao_municipal %>%
  left_join(
    area_original_poligonos,
    by = "fid",
    suffix = c("", "_original")
  )

# Distribuição proporcional do atributo area_km do PRODES:
# área do fragmento municipal / área geométrica original do polígono.
intersecao_municipal <- intersecao_municipal %>%
  mutate(
    proporcao_fragmento = if_else(
      area_geometrica_original > 0,
      area_geometrica_fragmento / area_geometrica_original,
      0
    ),
    proporcao_fragmento = pmin(
      pmax(proporcao_fragmento, 0),
      1
    ),
    area_prodes_fragmento =
      area_km_original * proporcao_fragmento
  )

# Diagnóstico da alocação
diagnostico_fragmentos <- intersecao_municipal %>%
  st_drop_geometry() %>%
  summarise(
    n_fragmentos = n(),
    n_fid = n_distinct(fid),
    n_area_ausente = sum(is.na(area_prodes_fragmento)),
    n_area_negativa = sum(area_prodes_fragmento < 0, na.rm = TRUE),
    n_proporcao_fora_intervalo = sum(
      proporcao_fragmento < 0 | proporcao_fragmento > 1,
      na.rm = TRUE
    ),
    area_prodes_distribuida =
      sum(area_prodes_fragmento, na.rm = TRUE)
  )

print(diagnostico_fragmentos)

if (diagnostico_fragmentos$n_area_ausente > 0 ||
    diagnostico_fragmentos$n_area_negativa > 0 ||
    diagnostico_fragmentos$n_proporcao_fora_intervalo > 0) {
  stop("A alocação proporcional apresentou valores inconsistentes.")
}


# 6. AGREGAÇÃO POR MUNICÍPIO E ANO -----------------------------

base_municipal_ano <- intersecao_municipal %>%
  st_drop_geometry() %>%
  group_by(year, CD_MUN, NM_MUN, NM_RGINT) %>%
  summarise(
    area_desmatada = sum(area_prodes_fragmento, na.rm = TRUE),
    n_poligonos = n_distinct(fid),
    .groups = "drop"
  )

print(
  base_municipal_ano %>%
    summarise(
      registros = n(),
      municipios = n_distinct(CD_MUN),
      anos = n_distinct(year),
      area_total = sum(area_desmatada, na.rm = TRUE)
    )
)


# 7. PAINEL MUNICIPAL COMPLETO ---------------------------------

cadastro_municipios <- mun_pa_eq %>%
  st_drop_geometry() %>%
  select(CD_MUN, NM_MUN, NM_RGINT, AREA_KM2) %>%
  distinct()

anos <- tibble(year = 2008:2025)

painel_completo <- tidyr::crossing(
  cadastro_municipios,
  anos
)

base_municipal_completa <- painel_completo %>%
  left_join(
    base_municipal_ano,
    by = c("year", "CD_MUN", "NM_MUN", "NM_RGINT")
  ) %>%
  mutate(
    area_desmatada = replace_na(area_desmatada, 0),
    n_poligonos = replace_na(n_poligonos, 0L)
  ) %>%
  arrange(CD_MUN, year)


# 8. VARIÁVEIS DERIVADAS ---------------------------------------

base_municipal_completa <- base_municipal_completa %>%
  mutate(
    taxa_desmat = (area_desmatada / AREA_KM2) * 100,
    densidade_poligonos = n_poligonos / AREA_KM2,
    area_log = log1p(area_desmatada)
  )


# 9. VALIDAÇÃO DO PAINEL ---------------------------------------

validacao_painel <- base_municipal_completa %>%
  summarise(
    n_registros = n(),
    n_municipios = n_distinct(CD_MUN),
    n_anos = n_distinct(year),
    ano_inicial = min(year),
    ano_final = max(year),
    n_zeros = sum(area_desmatada == 0),
    n_positivos = sum(area_desmatada > 0),
    n_ausentes = sum(is.na(area_desmatada)),
    n_negativos = sum(area_desmatada < 0, na.rm = TRUE),
    area_total = sum(area_desmatada, na.rm = TRUE)
  )

print(validacao_painel)

duplicidades <- base_municipal_completa %>%
  count(CD_MUN, year) %>%
  filter(n > 1)

if (nrow(duplicidades) > 0) {
  stop("Há duplicidades na combinação município-ano.")
}

if (nrow(base_municipal_completa) !=
    n_distinct(base_municipal_completa$CD_MUN) *
    n_distinct(base_municipal_completa$year)) {
  stop("O painel municipal não está balanceado.")
}

if (any(is.na(base_municipal_completa$AREA_KM2)) ||
    any(base_municipal_completa$AREA_KM2 <= 0, na.rm = TRUE)) {
  stop("Há área territorial municipal ausente ou não positiva.")
}


# 10. TOTAIS ANUAIS E RESUMO 2011-2025 -------------------------

totais_anuais <- base_municipal_completa %>%
  group_by(year) %>%
  summarise(
    area_total = sum(area_desmatada, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(year)

resumo_2011_2025 <- totais_anuais %>%
  filter(year >= 2011, year <= 2025) %>%
  summarise(
    acumulado = sum(area_total),
    media_anual = mean(area_total),
    ano_maximo = year[which.max(area_total)],
    valor_maximo = max(area_total),
    ano_minimo = year[which.min(area_total)],
    valor_minimo = min(area_total)
  )

print(totais_anuais)
print(resumo_2011_2025)


# 11. EXPORTAÇÃO -----------------------------------------------

# CSV: formato de intercâmbio e leitura em diferentes programas
write_csv(
  base_municipal_completa,
  file.path(
    diretorio_saida,
    "base_municipal_completa_2008_2025.csv"
  )
)

# RDS: preserva os tipos de dados do R
saveRDS(
  base_municipal_completa,
  file.path(
    diretorio_saida,
    "base_municipal_completa_2008_2025.rds"
  )
)

write_csv(
  totais_anuais,
  file.path(diretorio_saida, "totais_anuais_2008_2025.csv")
)

write_csv(
  resumo_2011_2025,
  file.path(diretorio_saida, "resumo_2011_2025.csv")
)

write_csv(
  validacao_painel,
  file.path(diretorio_saida, "validacao_painel.csv")
)

message(
  "Script 01 concluído. Arquivos salvos em: ",
  normalizePath(diretorio_saida)
)
