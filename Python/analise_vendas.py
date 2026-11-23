"""
Vendas Analytics — Análise Exploratória com Python
Autor: Daniel Mendes | Analista de Dados
Fonte: SQL Server 2017 | Banco: Vendas_Analytics
"""

import pyodbc
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import os

# ── CONFIGURAÇÃO ──────────────────────────────────────────
SERVER   = 'localhost'          # ou nome do seu servidor
DATABASE = 'Vendas_Analytics'
DRIVER   = 'ODBC Driver 17 for SQL Server'  # verifique o driver instalado

conn_str = (
    f"DRIVER={{{DRIVER}}};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
)

OUTPUT_DIR = 'charts'
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── PALETA ────────────────────────────────────────────────
PRIMARY = '#1565C0'
TEAL    = '#00897B'
ORANGE  = '#E65100'
GREEN   = '#2E7D32'
AMBER   = '#F57F17'
HDR     = '#0D1B40'
BG      = '#F5F8FF'

# ── CONEXÃO ───────────────────────────────────────────────
print("Conectando ao SQL Server...")
conn = pyodbc.connect(conn_str)
print("Conexão estabelecida com sucesso!\n")

def query(sql):
    return pd.read_sql(sql, conn)

# ── GRÁFICO 1 — Receita Mensal 2023 vs 2024 ──────────────
df1 = query("""
    SELECT mes, periodo, receita_ano_anterior, receita_total
    FROM vw_vendas_mensal_yoy
    WHERE ano = 2024
    ORDER BY mes
""")

fig, ax = plt.subplots(figsize=(12, 5), facecolor=BG)
ax.set_facecolor(BG)
ax.plot(df1['periodo'], df1['receita_ano_anterior'], color=TEAL,
        marker='o', linewidth=2, label='2023')
ax.plot(df1['periodo'], df1['receita_total'], color=PRIMARY,
        marker='o', linewidth=2, label='2024')
ax.fill_between(df1['periodo'], df1['receita_total'], alpha=0.08, color=PRIMARY)
ax.set_title('Receita Mensal — 2023 vs 2024', fontsize=14,
             fontweight='bold', color=HDR, pad=15)
ax.set_xlabel(''); ax.tick_params(colors=HDR)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(
    lambda x, _: f'R$ {x/1e6:.1f}M'))
ax.legend(); ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(f'{OUTPUT_DIR}/01_receita_mensal_yoy.png', dpi=150)
plt.close()
print('Gráfico 1 salvo')

# ── GRÁFICO 2 — Top 10 Produtos por Receita ───────────────
df2 = query("""
    SELECT TOP 10 produto, receita_total
    FROM vw_ranking_produtos_abc
    ORDER BY receita_total DESC
""")

fig, ax = plt.subplots(figsize=(10, 6), facecolor=BG)
ax.set_facecolor(BG)
bars = ax.barh(df2['produto'], df2['receita_total'], color=PRIMARY)
ax.bar_label(bars, fmt=lambda x: f'R$ {x/1e3:.0f}k', padding=5, color=HDR)
ax.set_title('Top 10 Produtos por Receita', fontsize=14,
             fontweight='bold', color=HDR, pad=15)
ax.invert_yaxis()
ax.xaxis.set_major_formatter(mticker.FuncFormatter(
    lambda x, _: f'R$ {x/1e3:.0f}k'))
ax.tick_params(colors=HDR); ax.grid(axis='x', alpha=0.3)
plt.tight_layout()
plt.savefig(f'{OUTPUT_DIR}/02_top10_produtos.png', dpi=150)
plt.close()
print('Gráfico 2 salvo')

# ── GRÁFICO 3 — Performance Vendedores ────────────────────
df3 = query("""
    SELECT nome, receita_realizada, meta_anual
    FROM vw_performance_vendedores
    WHERE ano = 2024
    ORDER BY receita_realizada DESC
""")

fig, ax = plt.subplots(figsize=(10, 6), facecolor=BG)
ax.set_facecolor(BG)
x = range(len(df3))
w = 0.4
ax.barh([i + w/2 for i in x], df3['meta_anual'],    height=w, color=AMBER,   label='Meta')
ax.barh([i - w/2 for i in x], df3['receita_realizada'], height=w, color=GREEN, label='Realizado')
ax.set_yticks(list(x)); ax.set_yticklabels(df3['nome'])
ax.set_title('Performance Vendedores 2024 — Realizado vs Meta',
             fontsize=14, fontweight='bold', color=HDR, pad=15)
ax.xaxis.set_major_formatter(mticker.FuncFormatter(
    lambda x, _: f'R$ {x/1e3:.0f}k'))
ax.invert_yaxis(); ax.legend(); ax.grid(axis='x', alpha=0.3)
plt.tight_layout()
plt.savefig(f'{OUTPUT_DIR}/03_performance_vendedores.png', dpi=150)
plt.close()
print('Gráfico 3 salvo')

# ── GRÁFICO 4 — Receita por Categoria ────────────────────
df4 = query("""
    SELECT categoria, SUM(receita_total) as receita
    FROM vw_ranking_produtos_abc
    GROUP BY categoria
    ORDER BY receita DESC
""")

fig, ax = plt.subplots(figsize=(10, 5), facecolor=BG)
ax.set_facecolor(BG)
colors = [PRIMARY, TEAL, ORANGE, AMBER, GREEN]
bars = ax.bar(df4['categoria'], df4['receita'],
              color=colors[:len(df4)])
ax.bar_label(bars, fmt=lambda x: f'R$ {x/1e3:.0f}k', padding=5, color=HDR)
ax.set_title('Receita por Categoria', fontsize=14,
             fontweight='bold', color=HDR, pad=15)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(
    lambda x, _: f'R$ {x/1e3:.0f}k'))
ax.tick_params(colors=HDR, axis='x', rotation=15)
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(f'{OUTPUT_DIR}/04_receita_categoria.png', dpi=150)
plt.close()
print('Gráfico 4 salvo')

# ── GRÁFICO 5 — Curva ABC Pareto ─────────────────────────
df5 = query("""
    SELECT produto, receita_total, participacao_acumulada_pct
    FROM vw_ranking_produtos_abc
    ORDER BY ranking
""")

fig, ax1 = plt.subplots(figsize=(14, 6), facecolor=BG)
ax1.set_facecolor(BG)
ax1.bar(range(len(df5)), df5['receita_total'], color=PRIMARY, alpha=0.7)
ax1.set_ylabel('Receita (R$)', color=HDR)
ax1.yaxis.set_major_formatter(mticker.FuncFormatter(
    lambda x, _: f'R$ {x/1e3:.0f}k'))

ax2 = ax1.twinx()
ax2.plot(range(len(df5)), df5['participacao_acumulada_pct'],
         color=ORANGE, linewidth=2.5, marker='')
ax2.axhline(80, color=ORANGE, linestyle='--', alpha=0.5, linewidth=1)
ax2.set_ylabel('Participação Acumulada (%)', color=ORANGE)
ax2.set_ylim(0, 105)

ax1.set_title('Curva ABC — Pareto de Produtos', fontsize=14,
              fontweight='bold', color=HDR, pad=15)
ax1.set_xticks([]); ax1.grid(axis='y', alpha=0.2)
plt.tight_layout()
plt.savefig(f'{OUTPUT_DIR}/05_curva_abc_pareto.png', dpi=150)
plt.close()
print('Gráfico 5 salvo')

conn.close()
print('\nTodos os gráficos salvos em', OUTPUT_DIR)