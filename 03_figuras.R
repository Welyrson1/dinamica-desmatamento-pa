# ============================================================
# PROJETO: DINÂMICAS DO DESMATAMENTO NO PARÁ
# SCRIPT 03.1 - PRODUÇÃO DAS FIGURAS (AJUSTE FIGURA 2)
# Período analítico: 2011-2025
# ============================================================
#
# Produz as três figuras finais do artigo/poster:
# 1. Evolução anual do desmatamento;
# 2. Variação da participação das RIs (2025 - 2011);
# 3. Mapa municipal do desmatamento acumulado.
#
# O script lê arquivos produzidos nos Scripts 01 e 02.
# ============================================================


# 0. PACOTES --------------------------------------------------

pacotes <- c("sf", "ggplot2", "scales", "dplyr", "tidyr",
              "readr", "grid", "systemfonts")

faltantes <- pacotes[
  !vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)
]

if (length(faltantes) > 0) {
  stop("Instale os pacotes: ", paste(faltantes, collapse = ", "))
}

library(sf)
library(ggplot2)
library(scales)
library(dplyr)
library(tidyr)
library(readr)
library(grid)


# 1. CAMINHOS -------------------------------------------------

diretorio_resultados <- "resultados"
diretorio_figuras <- "figuras_poster"

arquivo_base <- file.path(
  diretorio_resultados,
  "base_municipal_com_ri_2008_2025.rds"
)

arquivo_RI_ano <- file.path(
  diretorio_resultados,
  "desmatamento_RI_ano_2011_2025.csv"
)

# A malha municipal deve ser exportada/disponibilizada pelo Script 01.
# Este nome é uma convenção: confirme ou ajuste conforme o arquivo real.
arquivo_malha <- file.path(
  diretorio_resultados,
  "malha_municipal_PA.rds"
)

if (!file.exists(arquivo_base)) {
  stop("Base municipal com RI não encontrada: ", arquivo_base)
}

if (!file.exists(arquivo_RI_ano)) {
  stop("Arquivo de desmatamento por RI e ano não encontrado: ",
       arquivo_RI_ano)
}

if (!file.exists(arquivo_malha)) {
  stop(
    "Malha municipal não encontrada: ", arquivo_malha,
    "\nExporte mun_pa como RDS no Script 01 ou ajuste o caminho."
  )
}


# 2. LEITURA DOS ARQUIVOS -------------------------------------

base_municipal_com_ri <- readRDS(arquivo_base)

desmatamento_RI_ano <- read_csv(
  arquivo_RI_ano,
  show_col_types = FALSE
)

mun_pa <- readRDS(arquivo_malha)

objetos_necessarios <- c(
  "base_municipal_com_ri",
  "desmatamento_RI_ano",
  "mun_pa"
)

objetos_ausentes <- objetos_necessarios[
  !vapply(objetos_necessarios, exists, logical(1),
          inherits = TRUE)
]

if (length(objetos_ausentes) > 0) {
  stop("Objetos ausentes após a leitura: ",
       paste(objetos_ausentes, collapse = ", "))
}


# 3. FONTE ----------------------------------------------------

# A fonte Montserrat pode ser instalada no sistema operacional.
# Caso não esteja disponível, o script utiliza sans para evitar
# substituição silenciosa por fonte não especificada.

fonte_figura <- if (
  "Montserrat" %in% systemfonts::system_fonts()$family
) {
  "Montserrat"
} else {
  warning(
    "Montserrat não foi encontrada. As figuras usarão sans. ",
    "Instale Montserrat se desejar manter a fonte original."
  )
  "sans"
}


# 4. PALETA E PARÂMETROS --------------------------------------

azul <- "#073A70"
cinza <- "#9AA5B1"
cinza_grade <- "#E9EAEB"
cinza_texto <- "#52606D"
cinza_eixo <- "#C7CACC"
fundo_claro <- "#EAF0F7"
texto <- "#1F2933"

dir.create(
  diretorio_figuras,
  showWarnings = FALSE,
  recursive = TRUE
)

largura_figura <- 22
altura_figura <- 24
resolucao <- 300

pt_para_mm <- function(pt) pt * 25.4 / 72

tema_figuras <- theme_minimal(
  base_size = 28,
  base_family = fonte_figura
) +
  theme(
    text = element_text(
      family = fonte_figura,
      color = texto
    ),
    axis.title = element_text(
      size = 28,
      color = cinza_texto
    ),
    axis.text = element_text(
      size = 28,
      color = cinza_texto
    ),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(
      color = cinza_grade,
      linewidth = 0.6
    ),
    axis.line = element_line(
      color = cinza_eixo,
      linewidth = 0.5
    ),
    legend.title = element_text(
      size = 24,
      color = texto
    ),
    legend.text = element_text(
      size = 24,
      color = cinza_texto
    ),
    plot.title = element_blank(),
    plot.subtitle = element_blank(),
    plot.margin = margin(5, 5, 5, 5)
  )


# 5. FIGURA 1 - EVOLUÇÃO ANUAL -------------------------------

resultados_anuais <- base_municipal_com_ri %>%
  filter(year >= 2011, year <= 2025) %>%
  group_by(year) %>%
  summarise(
    area_desmatada = sum(area_desmatada, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(year)

ano_pico <- resultados_anuais %>%
  slice_max(
    area_desmatada,
    n = 1,
    with_ties = FALSE
  )

fig1 <- ggplot(
  resultados_anuais,
  aes(x = year, y = area_desmatada)
) +
  geom_line(
    color = azul,
    linewidth = 2
  ) +
  geom_point(
    color = azul,
    size = 4
  ) +
  geom_point(
    data = ano_pico,
    color = azul,
    size = 6
  ) +
  geom_label(
    data = ano_pico,
    aes(
      label = paste0(
        year, ": ",
        format(
          round(area_desmatada, 0),
          big.mark = ".",
          decimal.mark = ","
        ),
        " km²"
      )
    ),
    nudge_y = 450,
    size = pt_para_mm(28),
    family = fonte_figura,
    linewidth = 0,
    fill = fundo_claro,
    color = texto,
    label.padding = unit(0.18, "lines")
  ) +
  scale_x_continuous(
    breaks = 2011:2025,
    expand = expansion(mult = c(0.03, 0.03))
  ) +
  scale_y_continuous(
    labels = label_number(
      big.mark = ".",
      decimal.mark = ","
    ),
    expand = expansion(mult = c(0.03, 0.16))
  ) +
  labs(
    x = "Ano",
    y = "Área desmatada (km²)"
  ) +
  tema_figuras +
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1,
      vjust = 1
    ),
    legend.position = "none"
  )

ggsave(
  filename = file.path(
    diretorio_figuras,
    "figura1_evolucao_anual.png"
  ),
  plot = fig1,
  width = largura_figura,
  height = altura_figura,
  units = "cm",
  dpi = resolucao,
  bg = "white"
)


# 6. FIGURA 2 - VARIAÇÃO DA PARTICIPAÇÃO DAS RIs (AJUSTADA) ---

participacao_extremos <- desmatamento_RI_ano %>%
  filter(year %in% c(2011, 2025)) %>%
  select(year, RI, area_desmatada) %>%
  group_by(year) %>%
  mutate(
    participacao = area_desmatada /
      sum(area_desmatada, na.rm = TRUE) * 100
  ) %>%
  ungroup() %>%
  select(year, RI, participacao) %>%
  pivot_wider(
    names_from = year,
    values_from = participacao,
    names_prefix = "ano_"
  ) %>%
  mutate(
    variacao_pp = ano_2025 - ano_2011,
    sentido = if_else(
      variacao_pp >= 0,
      "Aumento",
      "Redução"
    )
  ) %>%
  arrange(variacao_pp)

fig2 <- ggplot(
  participacao_extremos,
  aes(
    x = reorder(RI, variacao_pp),
    y = variacao_pp,
    fill = sentido
  )
) +
  geom_hline(
    yintercept = 0,
    color = cinza_eixo,
    linewidth = 0.8
  ) +
  geom_col(
    width = 0.7,
    show.legend = FALSE
  ) +
  geom_text(
    aes(
      label = sprintf("%+.2f", variacao_pp),
      hjust = if_else(
        variacao_pp >= 0,
        -0.15,
        1.15
      )
    ),
    size = pt_para_mm(28),
    family = fonte_figura,
    color = texto
  ) +
  coord_flip(clip = "off") +
  scale_fill_manual(
    values = c(
      "Aumento" = azul,
      "Redução" = cinza
    ),
    guide = "none"
  ) +
  scale_y_continuous(
    breaks = c(-10, -5, 0, 5, 10),
    expand = expansion(mult = c(0.40, 0.40))
  ) +
  labs(
    x = NULL,
    y = "Variação (pontos percentuais)"
  ) +
  tema_figuras +
  theme(
    panel.grid.major.y = element_blank(),
    legend.position = "none"
  )

ggsave(
  filename = file.path(
    diretorio_figuras,
    "figura2_variacao_RI.png"
  ),
  plot = fig2,
  width = largura_figura,
  height = altura_figura,
  units = "cm",
  dpi = resolucao,
  bg = "white"
)


# 7. FIGURA 3 - MAPA MUNICIPAL -------------------------------

area_municipio <- base_municipal_com_ri %>%
  filter(year >= 2011, year <= 2025) %>%
  group_by(CD_MUN) %>%
  summarise(
    area_acumulada = sum(area_desmatada, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(CD_MUN = as.character(CD_MUN))

mapa_municipal <- mun_pa %>%
  mutate(CD_MUN = as.character(CD_MUN)) %>%
  left_join(
    area_municipio,
    by = "CD_MUN"
  ) %>%
  mutate(
    area_acumulada = replace_na(area_acumulada, 0)
  ) %>%
  st_transform(5880)

if (nrow(mapa_municipal) != 144) {
  warning(
    "A malha municipal contém ", nrow(mapa_municipal),
    " registros; confira se os 144 municípios estão presentes."
  )
}

fig3 <- ggplot(mapa_municipal) +
  geom_sf(
    aes(fill = area_acumulada),
    color = "white",
    linewidth = 0.12
  ) +
  scale_fill_gradient(
    low = fundo_claro,
    high = azul,
    breaks = breaks_pretty(n = 6),
    labels = label_number(
      accuracy = 1,
      big.mark = ".",
      decimal.mark = ","
    ),
    name = "Área acumulada (km²)",
    guide = guide_colorbar(
      direction = "horizontal",
      barwidth = unit(12, "cm"),
      barheight = unit(0.5, "cm"),
      title.position = "top",
      title.hjust = 0
    )
  ) +
  coord_sf(
    datum = NA,
    expand = FALSE
  ) +
  theme_void(
    base_size = 28,
    base_family = fonte_figura
  ) +
  theme(
    text = element_text(
      family = fonte_figura,
      color = texto
    ),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.title = element_text(
      size = 24,
      color = texto
    ),
    legend.text = element_text(
      size = 24,
      color = cinza_texto
    ),
    legend.key.width = unit(12, "cm"),
    plot.margin = margin(0, 5, 0, 5)
  )

ggsave(
  filename = file.path(
    diretorio_figuras,
    "figura3_mapa_municipal.png"
  ),
  plot = fig3,
  width = largura_figura,
  height = altura_figura,
  units = "cm",
  dpi = resolucao,
  bg = "white"
)


# 8. CONFERÊNCIA FINAL ----------------------------------------

arquivos_figuras <- file.path(
  diretorio_figuras,
  c(
    "figura1_evolucao_anual.png",
    "figura2_variacao_RI.png",
    "figura3_mapa_municipal.png"
  )
)

if (!all(file.exists(arquivos_figuras))) {
  stop("Nem todas as figuras foram exportadas.")
}

message(
  "\nScript 03 concluído. Figuras exportadas:\n",
  paste(arquivos_figuras, collapse = "\n"),
  "\nDimensões: 22 x 24 cm | Resolução: 300 dpi\n",
  "Fonte: ", fonte_figura, "\n"
)
