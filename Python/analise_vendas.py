"""
Vendas Analytics — Análise Exploratória com Python
Autor: Daniel Mendes | Analista de Dados
Fonte: SQL Server 17 | Banco: Vendas_Analytics
Saída: 6 gráficos com a identidade visual do dashboard, salvos em charts/
"""

import os
import pyodbc
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

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

# Gráficos salvos em charts/, na raiz do repositório (independe da pasta de execução)
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'charts')
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── PALETA (mesma do Power BI) ────────────────────────────
PRIMARY = '#1565C0'
LIGHT   = '#64B5F6'
TEAL    = '#00897B'
ORANGE  = '#E65100'
GREEN   = '#2E7D32'
AMBER   = '#F57F17'
GRAY    = '#90A4AE'
HDR     = '#0D1B40'
BG      = '#F5F8FF'

MESES = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez']


def br(valor, casas=1):
    """Formata número no padrão brasileiro (vírgula decimal)."""
    return f"{valor:,.{casas}f}".replace(",", "X").replace(".", ",").replace("X", ".")


def mil(x, _=None):
    return f"R$ {br(x / 1e3, 0)} mil"


def estilo(ax, titulo):
    ax.set_facecolor(BG)
    ax.set_title(titulo, fontsize=13, fontweight='bold', color=HDR, pad=15)
    ax.tick_params(colors=HDR)
    for lado in ['top', 'right']:
        ax.spines[lado].set_visible(False)


def salvar(fig, nome):
    fig.tight_layout()
    fig.savefig(os.path.join(OUTPUT_DIR, nome), dpi=150, facecolor=BG)
    plt.close(fig)
    print(f'  Salvo: charts/{nome}')


# ── CONEXÃO ───────────────────────────────────────────────
print("Conectando ao SQL Server...")
conn = pyodbc.connect(conn_str)
print("Conexão estabelecida com sucesso!\n")


def query(sql):
    return pd.read_sql(sql, conn)


# ── GRÁFICO 1 — Receita Mensal 2023 vs 2024 ──────────────
df1 = query("""
    SELECT ano, mes, receita_total
    FROM vw_vendas_mensal_yoy
    ORDER BY ano, mes
""")
p1 = df1.pivot(index='mes', columns='ano', values='receita_total')
cresc = (p1[2024].sum() / p1[2023].sum() - 1) * 100

fig, ax = plt.subplots(figsize=(12, 5), facecolor=BG)
x = [MESES[m - 1] for m in p1.index]
ax.plot(x, p1[2023], color=LIGHT, marker='o', linewidth=2, label='2023')
ax.plot(x, p1[2024], color=PRIMARY, marker='o', linewidth=2.5, label='2024')
ax.fill_between(x, p1[2024], alpha=0.08, color=PRIMARY)
estilo(ax, f'Receita cresce {br(cresc)}% em 2024, acima de 2023 em todos os meses')
ax.yaxis.set_major_formatter(mticker.FuncFormatter(mil))
ax.legend(frameon=False); ax.grid(axis='y', alpha=0.3)
salvar(fig, '01_receita_mensal_yoy.png')

# ── GRÁFICO 2 — Top 10 Produtos por Receita ───────────────
df2 = query("""
    SELECT TOP 10 produto, receita_total, participacao_pct
    FROM vw_ranking_produtos_abc
    ORDER BY receita_total DESC
""")
top2 = df2['participacao_pct'].iloc[:2].sum()

fig, ax = plt.subplots(figsize=(10, 6), facecolor=BG)
cores = [ORANGE, ORANGE] + [PRIMARY] * (len(df2) - 2)
bars = ax.barh(df2['produto'], df2['receita_total'], color=cores)
ax.bar_label(bars, labels=[f"{mil(v)} · {br(p)}%" for v, p in zip(df2['receita_total'], df2['participacao_pct'])],
             padding=5, color=HDR, fontsize=9)
estilo(ax, f'Dois produtos concentram {br(top2)}% da receita (2023–2024)')
ax.invert_yaxis()
ax.set_xlim(0, df2['receita_total'].max() * 1.3)
ax.xaxis.set_major_formatter(mticker.FuncFormatter(mil))
ax.grid(axis='x', alpha=0.3)
salvar(fig, '02_top10_produtos.png')

# ── GRÁFICO 3 — Performance Vendedores 2024 ───────────────
df3 = query("""
    SELECT nome, receita_realizada, meta_anual, atingimento_meta_pct
    FROM vw_performance_vendedores
    WHERE ano = 2024
    ORDER BY receita_realizada DESC
""")
bateram = int((df3['receita_realizada'] >= df3['meta_anual']).sum())

fig, ax = plt.subplots(figsize=(11, 6), facecolor=BG)
y = range(len(df3))
w = 0.4
ax.barh([i + w / 2 for i in y], df3['meta_anual'], height=w, color=GRAY, label='Meta')
ax.barh([i - w / 2 for i in y], df3['receita_realizada'], height=w, color=PRIMARY, label='Realizado')
for i, (r, a) in enumerate(zip(df3['receita_realizada'], df3['atingimento_meta_pct'])):
    ax.text(max(r, 0) + 6000, i - w / 2, f"{br(a)}%", va='center', fontsize=9,
            color=GREEN if a >= 100 else ORANGE, fontweight='bold')
ax.set_yticks(list(y)); ax.set_yticklabels(df3['nome'])
verbo = 'bateu' if bateram == 1 else 'bateram'
estilo(ax, f'Só {bateram} de {len(df3)} vendedores {verbo} a meta em 2024')
ax.xaxis.set_major_formatter(mticker.FuncFormatter(mil))
ax.invert_yaxis(); ax.legend(frameon=False, loc='lower right'); ax.grid(axis='x', alpha=0.3)
salvar(fig, '03_performance_vendedores.png')

# ── GRÁFICO 4 — Receita por Categoria ────────────────────
df4 = query("""
    SELECT categoria, SUM(receita_total) AS receita
    FROM vw_ranking_produtos_abc
    GROUP BY categoria
    ORDER BY receita DESC
""")
df4['pct'] = df4['receita'] / df4['receita'].sum() * 100

fig, ax = plt.subplots(figsize=(10, 5), facecolor=BG)
cores = [PRIMARY, PRIMARY] + [LIGHT] * (len(df4) - 2)
bars = ax.bar(df4['categoria'], df4['receita'], color=cores)
ax.bar_label(bars, labels=[f"{br(p)}%" for p in df4['pct']], padding=5, color=HDR)
estilo(ax, f"{df4['categoria'].iloc[0]} e {df4['categoria'].iloc[1]} somam "
           f"{br(df4['pct'].iloc[:2].sum())}% da receita (2023–2024)")
ax.yaxis.set_major_formatter(mticker.FuncFormatter(mil))
ax.tick_params(axis='x', rotation=15)
ax.grid(axis='y', alpha=0.3)
salvar(fig, '04_receita_categoria.png')

# ── GRÁFICO 5 — Curva ABC Pareto ─────────────────────────
df5 = query("""
    SELECT produto, receita_total, participacao_acumulada_pct, curva_abc
    FROM vw_ranking_produtos_abc
    ORDER BY ranking
""")
qtd_a = int((df5['curva_abc'] == 'A').sum())
cor_abc = {'A': PRIMARY, 'B': AMBER, 'C': GRAY}

fig, ax1 = plt.subplots(figsize=(14, 6), facecolor=BG)
ax1.bar(range(len(df5)), df5['receita_total'], color=[cor_abc[c] for c in df5['curva_abc']])
ax1.set_ylabel('Receita', color=HDR)
ax1.yaxis.set_major_formatter(mticker.FuncFormatter(mil))
ax1.set_xticks(range(len(df5)))
ax1.set_xticklabels(df5['produto'], rotation=40, ha='right', fontsize=8)

ax2 = ax1.twinx()
ax2.plot(range(len(df5)), df5['participacao_acumulada_pct'], color=ORANGE, linewidth=2.5)
for corte in (80, 95):
    ax2.axhline(corte, color=ORANGE, linestyle='--', alpha=0.4, linewidth=1)
    ax2.text(len(df5) - 0.5, corte + 1, f'{corte}%', color=ORANGE, fontsize=9, ha='right')
ax2.set_ylabel('Participação acumulada (%)', color=ORANGE)
ax2.set_ylim(0, 105)
for lado in ['top']:
    ax2.spines[lado].set_visible(False)

estilo(ax1, f'Curva ABC: {qtd_a} dos {len(df5)} produtos geram 80% da receita (2023–2024)')
ax1.grid(axis='y', alpha=0.2)
salvar(fig, '05_curva_abc_pareto.png')

# ── GRÁFICO 6 — Concentração da Receita 2024 ─────────────
df6 = query("""
    SELECT dimensao, item, participacao_pct, ranking
    FROM vw_concentracao_receita
    WHERE ano = 2024
""")
conc = [
    ('1 vendedor',  df6[(df6.dimensao == 'Vendedor') & (df6.ranking <= 1)]['participacao_pct'].sum()),
    ('3 clientes',  df6[(df6.dimensao == 'Cliente') & (df6.ranking <= 3)]['participacao_pct'].sum()),
    ('2 produtos',  df6[(df6.dimensao == 'Produto') & (df6.ranking <= 2)]['participacao_pct'].sum()),
]

fig, ax = plt.subplots(figsize=(10, 4.5), facecolor=BG)
nomes = [c[0] for c in conc]
vals = [c[1] for c in conc]
ax.barh(nomes, [100] * 3, color='#E3EAF5', height=0.55)
bars = ax.barh(nomes, vals, color=ORANGE, height=0.55)
ax.bar_label(bars, labels=[f"{br(v)}% da receita" for v in vals], padding=8, color=HDR, fontweight='bold')
estilo(ax, 'Receita de 2024 concentrada em poucos vendedores, clientes e produtos')
ax.set_xlim(0, 100)
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f'{x:.0f}%'))
ax.invert_yaxis()
salvar(fig, '06_concentracao_receita.png')

conn.close()
print('\nTodos os 6 gráficos salvos em charts/.')
