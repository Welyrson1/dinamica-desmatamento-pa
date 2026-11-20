# Dinâmicas do desmatamento no Pará: uma análise visual das Regiões de Integração entre 2011 e 2025

## 📌 Sobre o projeto

Este repositório reúne os códigos e a base de dados analítica utilizados no estudo **Dinâmicas do desmatamento no Pará: uma análise visual das Regiões de Integração entre 2011 e 2025**.

O estudo analisa a dinâmica temporal e espacial do desmatamento no estado do Pará, considerando os **144 municípios** e as **12 Regiões de Integração**, por meio de estatísticas descritivas, indicadores de participação relativa e recursos de visualização de dados.

O repositório foi organizado para documentar os procedimentos de processamento dos dados geoespaciais, integração territorial, análise e elaboração das figuras apresentadas no estudo.

---

## 🗺️ Área de estudo e período

* **Área geográfica:** Estado do Pará, Brasil.
* **Unidades territoriais:** 144 municípios e 12 Regiões de Integração.
* **Período de análise:** 2011–2025.

---

## 📊 Fontes de dados

Os dados utilizados no estudo são provenientes de fontes públicas:

* **PRODES/INPE:** dados geoespaciais de desmatamento da Amazônia brasileira, disponibilizados por meio da plataforma TerraBrasilis.
* **IBGE:** malha municipal utilizada na delimitação e identificação das unidades territoriais.
* **Tabela de correspondência municipal–Região de Integração:** utilizada para associar os municípios paraenses às respectivas Regiões de Integração.

Os dados originais podem ser obtidos nas plataformas oficiais:
* **TerraBrasilis/INPE:** [https://terrabrasilis.dpi.inpe.br/](https://terrabrasilis.dpi.inpe.br/)
* **IBGE:** [https://www.ibge.gov.br/](https://www.ibge.gov.br/)

---

## 📂 Organização dos scripts

Os scripts estão organizados em sequência, de acordo com as etapas de processamento e análise:

### 1. `01_construcao_base.R` – Construção e tratamento da base municipal
Realiza o processamento dos dados geoespaciais do PRODES e da malha municipal do IBGE, incluindo:
* Seleção dos dados referentes ao estado do Pará;
* Verificação e correção de geometrias;
* Operações de interseção espacial;
* Distribuição proporcional das áreas dos polígonos nas interseções territoriais;
* Agregação dos dados por município e ano;
* Construção da base municipal balanceada para o período de 2008 a 2025.

### 2. `02_integracao_ri_analises.R` – Integração das Regiões de Integração e análises
Realiza a integração da base municipal à tabela de correspondência das Regiões de Integração (`RI-Municipio.xlsx`) e organiza os dados para o período analítico de 2011 a 2025. Inclui os procedimentos de agregação e cálculo dos indicadores utilizados na análise temporal e regional.

### 3. `03_figuras.R` – Elaboração das figuras
Realiza a geração das figuras utilizadas no estudo:
* **Figura 1** – Evolução anual da área desmatada no Pará;
* **Figura 2** – Variação da participação das Regiões de Integração no desmatamento estadual entre 2011 e 2025;
* **Figura 3** – Distribuição municipal da área acumulada de desmatamento no Pará.

---

## 🗄️ Base de dados analítica

O repositório disponibiliza a base de dados analítica (`base_municipal_com_ri_2008_2025.rds`) utilizada nas etapas de agregação e análise, bem como a tabela de correspondência dos municípios às Regiões de Integração (`RI-Municipio.xlsx`).

A base analítica foi organizada em estrutura municipal e temporal, permitindo a agregação dos dados nas escalas estadual, municipal e regional.

---

## 💻 Ambiente de análise

O processamento e as análises foram realizados no ambiente **R**, com utilização, principalmente, dos seguintes pacotes:

* `sf`
* `tidyverse`
* `dplyr`
* `ggplot2`

---

## ⚙️ Como reproduzir as análises

Para reproduzir os procedimentos:

1. Obtenha os dados geoespaciais originais do **PRODES/INPE** e a malha municipal do **IBGE** nas fontes oficiais indicadas.
2. Organize os arquivos de entrada conforme os caminhos definidos nos scripts.
3. Execute os scripts na sequência indicada:
   * `01_construcao_base.R` – construção e tratamento da base municipal;
   * `02_integracao_ri_analises.R` – integração das Regiões de Integração e análises;
   * `03_figuras.R` – elaboração das figuras.
4. Disponibilize os arquivos auxiliares necessários, incluindo a tabela de correspondência municipal–Região de Integração (`RI-Municipio.xlsx`) e a base analítica (`base_municipal_com_ri_2008_2025.rds`), conforme a organização do repositório.

---

## 📚 Referência ao estudo

> Silva, Welyrson Carlos Coutinho; Correa, Alan Tiago; Maciel, Marinalva Cardoso. **Dinâmicas do desmatamento no Pará: uma análise visual das Regiões de Integração entre 2011 e 2025**.

