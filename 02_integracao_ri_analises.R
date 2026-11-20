# ============================================================
# PROJETO: DINAMICAS DO DESMATAMENTO NO PARA
# SCRIPT 02 - INTEGRACAO DAS REGIOES DE INTEGRACAO E ANALISES
# Periodo analitico: 2011-2025
# ============================================================
# Objetivos:
# 1. Ler a base municipal produzida pelo Script 01;
# 2. integrar a classificacao Municipio-Regiao de Integracao (RI);
# 3. validar a classificacao e a cobertura municipal;
# 4. produzir tabelas estaduais, regionais e municipais;
# 5. comparar a participacao regional em 2011 e 2025;
# 6. exportar os resultados usados no artigo e nas figuras.
#
# A tabela Municipio-RI e uma compilacao dos autores com base
# na legislacao estadual. Conferir arquivo e campos abaixo.
# ============================================================

# 0. PACOTES --------------------------------------------------
pacotes <- c("dplyr", "tidyr", "readr", "readxl", "janitor", "tibble")
faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes) > 0) stop("Instale os pacotes: ", paste(faltantes, collapse = ", "))
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(janitor)
library(tibble)

# 1. CAMINHOS E CONFIGURACAO -------------------------------
diretorio_dados <- "."
diretorio_resultados <- "resultados"
arquivo_base <- file.path(diretorio_resultados, "base_municipal_completa_2008_2025.rds")
arquivo_correspondencia <- file.path(diretorio_dados, "RI-Municipio.xlsx")
nome_planilha <- "Plan1"
if (!file.exists(arquivo_base)) stop("Base municipal nao encontrada. Execute primeiro o Script 01.")
if (!file.exists(arquivo_correspondencia)) stop("Planilha Municipio-RI nao encontrada. Confira o caminho.")

# 2. LEITURA -------------------------------------------------
base_municipal <- readRDS(arquivo_base)
correspondencia_raw <- read_excel(arquivo_correspondencia, sheet = nome_planilha) %>% clean_names()
message("Campos encontrados na planilha de correspondencia:")
print(names(correspondencia_raw))

# 3. PREPARACAO DA CORRESPONDENCIA ---------------------------
# Espera campos COD_IBGE e RI (apos clean_names: cod_ibge e ri).
# Se os nomes forem diferentes, ajuste nesta secao.
if (!"cod_ibge" %in% names(correspondencia_raw)) stop("Campo cod_ibge nao encontrado na planilha Municipio-RI.")
if (!"ri" %in% names(correspondencia_raw)) stop("Campo ri nao encontrado na planilha Municipio-RI.")

correspondencia_ri <- correspondencia_raw %>%
  transmute(CD_MUN = as.character(cod_ibge), RI = as.character(ri)) %>%
  mutate(CD_MUN = trimws(CD_MUN), RI = trimws(RI),
         RI = sub("^RI\\s*[-:]?\\s*", "", RI, ignore.case = TRUE))
# IBGE codigos municipais normalmente possuem 7 digitos; completar zeros a esquerda se necessario.
correspondencia_ri <- correspondencia_ri %>%
  mutate(CD_MUN = if_else(grepl("^[0-9]+$", CD_MUN),
                          paste0(strrep("0", pmax(0, 7 - nchar(CD_MUN))), CD_MUN), CD_MUN))

duplicidades_ri <- correspondencia_ri %>% count(CD_MUN) %>% filter(n > 1)
if (nrow(duplicidades_ri) > 0) { print(duplicidades_ri); stop("Codigos municipais duplicados na tabela Municipio-RI.") }
if (any(is.na(correspondencia_ri$RI) | correspondencia_ri$RI == "")) stop("Ha classificacoes RI ausentes na planilha.")

# 4. PADRONIZACAO DOS CODIGOS NA BASE ------------------------
base_municipal <- base_municipal %>% mutate(CD_MUN = as.character(CD_MUN)) %>%
  mutate(CD_MUN = if_else(grepl("^[0-9]+$", CD_MUN),
                          paste0(strrep("0", pmax(0, 7 - nchar(CD_MUN))), CD_MUN), CD_MUN))

# 5. INCORPORACAO DA RI --------------------------------------
base_municipal_com_ri <- base_municipal %>% select(-any_of("RI")) %>%
  left_join(correspondencia_ri, by = "CD_MUN")

validacao_ri <- base_municipal_com_ri %>% summarise(
  n_registros = n(), n_municipios = n_distinct(CD_MUN), n_anos = n_distinct(year),
  n_RI = n_distinct(RI), n_RI_ausente = sum(is.na(RI)),
  ano_inicial = min(year), ano_final = max(year))
print(validacao_ri)
if (any(is.na(base_municipal_com_ri$RI))) {
  print(base_municipal_com_ri %>% filter(is.na(RI)) %>% distinct(CD_MUN, NM_MUN))
  stop("Municipios sem RI apos a integracao.")
}
if (n_distinct(base_municipal_com_ri$CD_MUN) != 144) warning("Base integrada nao contem 144 municipios.")
if (n_distinct(base_municipal_com_ri$RI) != 12) warning("Base integrada nao contem exatamente 12 RIs.")

# 6. RECORTE ANALITICO ----------------------------------------
base_analise <- base_municipal_com_ri %>% filter(year >= 2011, year <= 2025) %>% arrange(CD_MUN, year)
if (nrow(base_analise) != 144 * 15) warning("Recorte 2011-2025 nao apresenta 2160 registros esperados.")

# 7. TOTAL ESTADUAL ANUAL ------------------------------------
totais_anuais_2011_2025 <- base_analise %>% group_by(year) %>% summarise(
  area_total = sum(area_desmatada, na.rm = TRUE), n_poligonos = sum(n_poligonos, na.rm = TRUE), .groups = "drop") %>% arrange(year)

# 8. TOTAL E PARTICIPACAO POR RI NO PERIODO -------------------
total_ri_periodo <- base_analise %>% group_by(RI) %>% summarise(
  area_acumulada = sum(area_desmatada, na.rm = TRUE), .groups = "drop") %>%
  mutate(participacao_percentual = 100 * area_acumulada / sum(area_acumulada)) %>% arrange(desc(area_acumulada))

# 9. RI POR ANO ------------------------------------------------
desmatamento_RI_ano <- base_analise %>% group_by(RI, year) %>% summarise(
  area_desmatada = sum(area_desmatada, na.rm = TRUE), n_poligonos = sum(n_poligonos, na.rm = TRUE), .groups = "drop") %>% arrange(RI, year)

# 10. PARTICIPACAO DE CADA RI POR ANO --------------------------
participacao_RI_ano <- desmatamento_RI_ano %>% group_by(year) %>% mutate(
  total_estadual = sum(area_desmatada, na.rm = TRUE),
  participacao_percentual = if_else(total_estadual > 0, 100 * area_desmatada / total_estadual, 0)) %>%
  ungroup() %>% select(RI, year, area_desmatada, total_estadual, participacao_percentual)

# 11. COMPARACAO 2011 E 2025 ----------------------------------
participacao_2011_2025 <- participacao_RI_ano %>% filter(year %in% c(2011, 2025)) %>%
  select(RI, year, participacao_percentual) %>% pivot_wider(names_from = year, values_from = participacao_percentual,
  names_prefix = "participacao_") %>% mutate(variacao_pp = participacao_2025 - participacao_2011) %>% arrange(desc(variacao_pp))

# 12. RESUMO MUNICIPAL -----------------------------------------
resumo_municipal_2011_2025 <- base_analise %>% group_by(CD_MUN, NM_MUN, RI) %>% summarise(
  area_acumulada = sum(area_desmatada, na.rm = TRUE), n_poligonos = sum(n_poligonos, na.rm = TRUE), .groups = "drop") %>% arrange(desc(area_acumulada))

# 13. RESUMO ESTADUAL ------------------------------------------
resumo_estadual_2011_2025 <- totais_anuais_2011_2025 %>% summarise(
  acumulado = sum(area_total, na.rm = TRUE), media_anual = mean(area_total, na.rm = TRUE),
  ano_maximo = year[which.max(area_total)], valor_maximo = max(area_total, na.rm = TRUE),
  ano_minimo = year[which.min(area_total)], valor_minimo = min(area_total, na.rm = TRUE))

# 14. VALIDACOES -----------------------------------------------
validacao_recorte <- base_analise %>% summarise(
  n_registros = n(), n_municipios = n_distinct(CD_MUN), n_anos = n_distinct(year), n_RI = n_distinct(RI),
  n_ausentes_area = sum(is.na(area_desmatada)), n_ausentes_RI = sum(is.na(RI)),
  n_negativos = sum(area_desmatada < 0, na.rm = TRUE))
print(validacao_recorte)
print(resumo_estadual_2011_2025)
print(total_ri_periodo)
print(participacao_2011_2025)
if (any(is.na(base_analise$RI)) || any(is.na(base_analise$area_desmatada)) ||
    any(base_analise$area_desmatada < 0, na.rm = TRUE)) stop("Base analitica apresenta inconsistencias.")

# 15. EXPORTACAO -----------------------------------------------
if (!dir.exists(diretorio_resultados)) dir.create(diretorio_resultados, recursive = TRUE)
saveRDS(base_municipal_com_ri, file.path(diretorio_resultados, "base_municipal_com_ri_2008_2025.rds"))
write_csv(base_municipal_com_ri, file.path(diretorio_resultados, "base_municipal_com_ri_2008_2025.csv"))
write_csv(base_analise, file.path(diretorio_resultados, "base_municipal_com_ri_2011_2025.csv"))
write_csv(totais_anuais_2011_2025, file.path(diretorio_resultados, "totais_anuais_2011_2025.csv"))
write_csv(total_ri_periodo, file.path(diretorio_resultados, "total_ri_2011_2025.csv"))
write_csv(desmatamento_RI_ano, file.path(diretorio_resultados, "desmatamento_RI_ano_2011_2025.csv"))
write_csv(participacao_RI_ano, file.path(diretorio_resultados, "participacao_RI_ano_2011_2025.csv"))
write_csv(participacao_2011_2025, file.path(diretorio_resultados, "participacao_RI_comparacao_2011_2025.csv"))
write_csv(resumo_municipal_2011_2025, file.path(diretorio_resultados, "resumo_municipal_2011_2025.csv"))
write_csv(resumo_estadual_2011_2025, file.path(diretorio_resultados, "resumo_estadual_2011_2025.csv"))
write_csv(validacao_ri, file.path(diretorio_resultados, "validacao_integracao_RI.csv"))
write_csv(validacao_recorte, file.path(diretorio_resultados, "validacao_recorte_2011_2025.csv"))
message("Script 02 concluido. Arquivos exportados para: ", normalizePath(diretorio_resultados))
