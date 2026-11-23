# 📊 Vendas Analytics Dashboard

> Pipeline completo de Análise Comercial: SQL Server → Power BI → Python

![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![pandas](https://img.shields.io/badge/pandas-150458?style=for-the-badge&logo=pandas&logoColor=white)
![matplotlib](https://img.shields.io/badge/matplotlib-11557c?style=for-the-badge&logo=python&logoColor=white)

---

## 🎯 Sobre o Projeto

Dashboard comercial interativo desenvolvido como projeto de portfólio, cobrindo o ciclo completo de análise de dados — desde a modelagem em SQL Server até a visualização em Power BI e análise exploratória em Python.

O projeto simula o ambiente analítico de uma empresa de tecnologia B2B com receita anual na faixa de R$ 1,5 Mi, abrangendo 4 páginas analíticas integradas com navegação fluida entre visões estratégicas de vendas, produtos e performance de vendedores.

---

## 🏗️ Arquitetura do Pipeline

```
SQL Server (Views)  →  Power BI (Dashboard)  →  Python (Análise)  →  GitHub
      ↓                        ↓                       ↓
  Modelagem               Storytelling            Visualizações
  com Views               com 4 páginas           matplotlib
```

---

## 📁 Estrutura do Repositório

```
projeto-vendas-analytics/
│
├── sql/
│   └── Vendas_analytics_projeto.sql   # Script completo (tabelas, dados e views)
│
├── Python/
│   └── analise_vendas.py              # Script de análise Python
│
├── Backgrounds/                       # Backgrounds customizados do dashboard
│   ├── bg_inicio.png
│   ├── bg_visao_geral.png
│   ├── bg_produtos.png
│   └── bg_vendedores.png
│
├── charts/                            # Gráficos gerados via Python
│   ├── 01_receita_mensal_yoy.png
│   ├── 02_top10_produtos.png
│   ├── 03_performance_vendedores.png
│   ├── 04_receita_categoria.png
│   └── 05_curva_abc_pareto.png
│
├── Screenshots/                       # Capturas das páginas do dashboard
│   ├── Início.png
│   ├── Visão Geral.png
│   ├── Produtos.png
│   └── Vendedores.png
│
└── Vendas_Analytics_Dashboard.pbix    # Arquivo Power BI
```

---

## 📊 Páginas do Dashboard

### 1 — Início
Capa do projeto com identidade visual, resumo do escopo analítico, stack tecnológica utilizada e botões de navegação para as demais páginas. Inclui painel de informações interativo acionado por botão.

### 2 — Visão Geral
KPIs estratégicos anuais: Receita 2024, Crescimento YoY, Total de Pedidos e Ticket Médio. Comparativo mensal 2023 vs 2024 com gráfico de linhas e área de receita acumulada do ano.

### 3 — Produtos
Análise da Curva ABC com ranking de produtos por receita, classificação A/B/C com formatação condicional e tabela de detalhamento com desconto médio por produto. Filtro por categoria.

### 4 — Vendedores
Performance individual de cada vendedor com comparativo Realizado vs Meta, ranking por receita e indicadores de atingimento. Filtro por ano.

---

## 🗄️ Modelagem de Dados (SQL Server)

O banco `Vendas_Analytics` contém tabelas relacionais e 6 views otimizadas para consumo no Power BI:

**Views:**
- `vw_vendas_mensal_yoy` — receita mensal com comparativo ano anterior
- `vw_kpis_anuais` — KPIs consolidados por ano
- `vw_ranking_produtos_abc` — ranking e classificação ABC por receita
- `vw_vendas_categoria_acumulado` — receita acumulada por categoria
- `vw_performance_vendedores` — realizado, meta e % atingimento por vendedor
- `vw_analise_clientes` — análise de base de clientes ativos

---

## 🐍 Análise Python

Script independente que conecta diretamente ao SQL Server via `pyodbc` e gera 5 visualizações analíticas em matplotlib com identidade visual alinhada ao dashboard:

| # | Gráfico | Tipo |
|---|---------|------|
| 01 | Receita Mensal — 2023 vs 2024 | Linhas com área |
| 02 | Top 10 Produtos por Receita | Barras horizontais |
| 03 | Performance Vendedores 2024 — Realizado vs Meta | Barras agrupadas |
| 04 | Receita por Categoria | Barras verticais |
| 05 | Curva ABC — Pareto de Produtos | Barras + linha acumulada |

### Como executar

```bash
# 1. Criar e ativar ambiente virtual
python -m venv venv
venv\Scripts\activate          # Windows

# 2. Instalar dependências
pip install pyodbc pandas matplotlib seaborn sqlalchemy

# 3. Configurar conexão em analise_vendas.py
SERVER   = "localhost"         # seu servidor SQL Server
DATABASE = "Vendas_Analytics"

# 4. Executar
python analise_vendas.py
# → Gráficos salvos em charts/
```

---

## 🎨 Identidade Visual

| Cor | Hex | Uso |
|-----|-----|-----|
| Azul Escuro | `#0D1B40` | Header e títulos |
| Azul Primário | `#1565C0` | Série principal / KPIs positivos |
| Teal | `#00897B` | Série secundária / 2023 |
| Laranja | `#E65100` | Navegação e destaques |
| Verde | `#2E7D32` | Metas atingidas |
| Âmbar | `#F57F17` | Alertas e comparativos |
| Fundo | `#F5F8FF` | Background das páginas |

---

## 🛠️ Stack Tecnológica

| Camada | Tecnologia |
|--------|-----------|
| Banco de dados | SQL Server 17 |
| Modelagem | Views SQL (6 views analíticas) |
| Visualização | Power BI Desktop |
| Análise | Python 3 · pandas · matplotlib · pyodbc · seaborn |
| Versionamento | Git · GitHub |

---

## 👤 Autor

**Daniel Mendes**  
Analista de Dados | Power BI · SQL · Python  
[LinkedIn](https://www.linkedin.com/in/danielgmendes) · [GitHub](https://github.com/DanielMendes-Dados)

---

*Projeto desenvolvido para portfólio profissional — dados simulados.*