-- ============================================================
-- VENDAS ANALYTICS — Script Completo
-- Banco: Vendas_Analytics | SQL Server
-- Inclui: Tabelas, Dados Simulados e 6 Views Analíticas
-- Técnicas: CTEs, Window Functions (LAG, RANK, SUM OVER),
--           Running Total, Classificação ABC
-- Autor: Daniel Luiz Gondim Mendes Bezerra
-- ============================================================

-- 1. CRIAR E USAR O BANCO
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Vendas_Analytics')
    CREATE DATABASE Vendas_Analytics;
GO

USE Vendas_Analytics;
GO

-- 2. CRIAR TABELAS
-- ============================================================

-- Dimensão: Regiões
IF OBJECT_ID('dim_regioes', 'U') IS NOT NULL DROP TABLE dim_regioes;
CREATE TABLE dim_regioes (
    id_regiao     INT PRIMARY KEY,
    regiao        VARCHAR(50) NOT NULL,
    estado        VARCHAR(50) NOT NULL,
    cidade        VARCHAR(80) NOT NULL
);

-- Dimensão: Vendedores
IF OBJECT_ID('dim_vendedores', 'U') IS NOT NULL DROP TABLE dim_vendedores;
CREATE TABLE dim_vendedores (
    id_vendedor   INT PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    cargo         VARCHAR(60)  NOT NULL,
    id_regiao     INT          NOT NULL,
    meta_anual    DECIMAL(12,2) NOT NULL
);

-- Dimensão: Categorias e Produtos
IF OBJECT_ID('dim_produtos', 'U') IS NOT NULL DROP TABLE dim_produtos;
CREATE TABLE dim_produtos (
    id_produto    INT PRIMARY KEY,
    produto       VARCHAR(100) NOT NULL,
    categoria     VARCHAR(60)  NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL
);

-- Dimensão: Clientes
IF OBJECT_ID('dim_clientes', 'U') IS NOT NULL DROP TABLE dim_clientes;
CREATE TABLE dim_clientes (
    id_cliente    INT PRIMARY KEY,
    razao_social  VARCHAR(120) NOT NULL,
    segmento      VARCHAR(60)  NOT NULL,
    id_regiao     INT          NOT NULL
);

-- Fato: Vendas
IF OBJECT_ID('fato_vendas', 'U') IS NOT NULL DROP TABLE fato_vendas;
CREATE TABLE fato_vendas (
    id_venda      INT IDENTITY(1,1) PRIMARY KEY,
    data_venda    DATE            NOT NULL,
    id_produto    INT             NOT NULL,
    id_cliente    INT             NOT NULL,
    id_vendedor   INT             NOT NULL,
    quantidade    INT             NOT NULL,
    preco_venda   DECIMAL(10,2)   NOT NULL,
    desconto_pct  DECIMAL(5,2)    NOT NULL DEFAULT 0,
    receita_bruta AS (quantidade * preco_venda) PERSISTED,
    receita_liquida AS (quantidade * preco_venda * (1 - desconto_pct / 100.0)) PERSISTED
);
GO

-- 3. POPULAR DIMENSÕES
-- ============================================================

INSERT INTO dim_regioes VALUES
(1, 'Sudeste', 'São Paulo',   'São Paulo'),
(2, 'Sudeste', 'Rio de Janeiro', 'Rio de Janeiro'),
(3, 'Sul',     'Paraná',     'Curitiba'),
(4, 'Sul',     'Rio Grande do Sul', 'Porto Alegre'),
(5, 'Centro-Oeste', 'Goiás', 'Goiânia'),
(6, 'Nordeste', 'Bahia',     'Salvador'),
(7, 'Nordeste', 'Pernambuco','Recife'),
(8, 'Norte',   'Pará',       'Belém');

INSERT INTO dim_vendedores VALUES
(1, 'Carlos Andrade',   'Executivo Sênior',   1, 480000),
(2, 'Fernanda Lima',    'Executivo Sênior',   2, 420000),
(3, 'Ricardo Souza',    'Executivo Pleno',    3, 360000),
(4, 'Mariana Costa',    'Executivo Pleno',    4, 340000),
(5, 'André Oliveira',   'Executivo Júnior',   5, 300000),
(6, 'Patrícia Nunes',   'Executivo Júnior',   6, 280000),
(7, 'Bruno Santos',     'Executivo Júnior',   7, 260000),
(8, 'Juliana Ferreira', 'Executivo Pleno',    1, 380000);

INSERT INTO dim_produtos VALUES
(1,  'Notebook Pro 15',         'Informática',    4200.00),
(2,  'Monitor Ultrawide 34"',   'Informática',    2800.00),
(3,  'Teclado Mecânico',        'Periféricos',     450.00),
(4,  'Mouse Ergonômico',        'Periféricos',     220.00),
(5,  'Headset Premium',         'Periféricos',     380.00),
(6,  'Switch 24 Portas',        'Redes',          1800.00),
(7,  'Roteador Corporativo',    'Redes',          2400.00),
(8,  'Servidor Rack 1U',        'Infraestrutura', 12000.00),
(9,  'No-break 2200VA',         'Infraestrutura',  1600.00),
(10, 'Câmera IP 4MP',           'Segurança',       680.00),
(11, 'DVR 16 Canais',           'Segurança',       950.00),
(12, 'Licença Office 365',      'Software',        180.00),
(13, 'Antivírus Corporativo',   'Software',        120.00),
(14, 'Impressora Laser Color',  'Impressão',      1900.00),
(15, 'Scanner Documental',      'Impressão',      1400.00);

INSERT INTO dim_clientes VALUES
(1,  'Construtora Alpha Ltda',       'Construção Civil',  1),
(2,  'TechSolve Consultoria',        'TI & Consultoria',  1),
(3,  'Clínica Saúde Total',          'Saúde',             2),
(4,  'Educação Premium S/A',         'Educação',          2),
(5,  'Distribuidora Sul Comércio',   'Varejo',            3),
(6,  'Escritório Contábil Norte',    'Serviços',          4),
(7,  'Agro Center Ltda',             'Agronegócio',       5),
(8,  'Shopping Nordeste SA',         'Varejo',            6),
(9,  'Prefeitura Municipal Recife',  'Governo',           7),
(10, 'Madeireira Pará Ltda',         'Indústria',         8),
(11, 'Banco Regional SA',            'Financeiro',        1),
(12, 'Hotel Palace',                 'Hotelaria',         2),
(13, 'Redes Farma S/A',              'Farmácias',         3),
(14, 'Colégio Bem Educar',           'Educação',          4),
(15, 'Supermercado Central',         'Varejo',            5);
GO

-- 4. POPULAR FATO_VENDAS (2023 e 2024 — ~400 registros)
-- ============================================================

-- Procedimento auxiliar para gerar vendas de forma controlada
-- Dados distribuídos por mês para criar sazonalidade realista

-- 2023 — Janeiro a Dezembro
INSERT INTO fato_vendas (data_venda, id_produto, id_cliente, id_vendedor, quantidade, preco_venda, desconto_pct) VALUES
-- Janeiro 2023
('2023-01-05', 1, 2, 1, 2, 4200.00, 5.0),
('2023-01-08', 3, 1, 1, 5, 450.00, 0.0),
('2023-01-10', 12,2, 2, 10,180.00, 0.0),
('2023-01-12', 6, 11,2, 1, 1800.00,3.0),
('2023-01-15', 4, 3, 3, 4, 220.00, 0.0),
('2023-01-18', 10,8, 6, 3, 680.00, 2.0),
('2023-01-20', 14,4, 2, 1, 1900.00,0.0),
('2023-01-22', 8, 9, 1, 1,12000.00,8.0),
('2023-01-25', 13,5, 3, 8, 120.00, 0.0),
('2023-01-28', 2, 11,1, 2, 2800.00,5.0),
-- Fevereiro 2023
('2023-02-03', 1, 2, 1, 1, 4200.00,5.0),
('2023-02-06', 5, 3, 3, 3, 380.00, 0.0),
('2023-02-08', 7, 11,2, 1, 2400.00,4.0),
('2023-02-10', 12,14,4, 15,180.00, 0.0),
('2023-02-13', 9, 6, 4, 2, 1600.00,2.0),
('2023-02-15', 3, 2, 1, 8, 450.00, 0.0),
('2023-02-18', 10,9, 6, 5, 680.00, 3.0),
('2023-02-20', 4, 5, 3, 6, 220.00, 0.0),
('2023-02-22', 13,13,5, 20,120.00, 0.0),
('2023-02-25', 11,8, 6, 2, 950.00, 2.0),
-- Março 2023
('2023-03-02', 8, 9, 1, 2,12000.00,10.0),
('2023-03-05', 1, 2, 1, 3, 4200.00, 7.0),
('2023-03-08', 6, 11,2, 2, 1800.00, 3.0),
('2023-03-10', 2, 4, 2, 1, 2800.00, 5.0),
('2023-03-12', 15,3, 3, 2, 1400.00, 0.0),
('2023-03-15', 12,2, 1, 20,180.00, 0.0),
('2023-03-18', 5, 12,2, 4, 380.00, 0.0),
('2023-03-20', 3, 1, 1, 10,450.00, 0.0),
('2023-03-22', 7, 7, 5, 1, 2400.00, 4.0),
('2023-03-25', 4, 15,5, 8, 220.00, 0.0),
('2023-03-28', 10,8, 6, 4, 680.00, 2.0),
-- Abril 2023
('2023-04-04', 1, 11,1, 2, 4200.00, 5.0),
('2023-04-06', 9, 6, 4, 3, 1600.00, 2.0),
('2023-04-08', 13,13,5, 25,120.00, 0.0),
('2023-04-10', 3, 2, 1, 7, 450.00, 0.0),
('2023-04-12', 6, 9, 2, 2, 1800.00, 3.0),
('2023-04-15', 14,4, 2, 2, 1900.00, 0.0),
('2023-04-18', 12,5, 3, 15,180.00, 0.0),
('2023-04-20', 2, 11,1, 1, 2800.00, 5.0),
('2023-04-22', 11,8, 6, 3, 950.00, 2.0),
('2023-04-25', 4, 3, 3, 5, 220.00, 0.0),
-- Maio 2023
('2023-05-03', 8, 9, 1, 1,12000.00, 8.0),
('2023-05-06', 1, 2, 1, 2, 4200.00, 5.0),
('2023-05-08', 7, 11,2, 2, 2400.00, 4.0),
('2023-05-10', 15,3, 3, 1, 1400.00, 0.0),
('2023-05-12', 5, 12,2, 5, 380.00, 0.0),
('2023-05-15', 12,2, 1, 20,180.00, 0.0),
('2023-05-18', 10,8, 6, 6, 680.00, 2.0),
('2023-05-20', 3, 1, 1, 8, 450.00, 0.0),
('2023-05-22', 6, 7, 5, 1, 1800.00, 3.0),
('2023-05-25', 13,15,5, 20,120.00, 0.0),
-- Junho 2023
('2023-06-02', 1, 2, 1, 3, 4200.00, 5.0),
('2023-06-05', 9, 6, 4, 2, 1600.00, 2.0),
('2023-06-08', 2, 4, 2, 2, 2800.00, 5.0),
('2023-06-10', 8, 9, 1, 1,12000.00,10.0),
('2023-06-12', 6, 11,2, 2, 1800.00, 3.0),
('2023-06-15', 3, 2, 1, 10,450.00, 0.0),
('2023-06-18', 14,4, 2, 1, 1900.00, 0.0),
('2023-06-20', 12,5, 3, 15,180.00, 0.0),
('2023-06-22', 10,8, 6, 5, 680.00, 2.0),
('2023-06-25', 7, 7, 5, 1, 2400.00, 4.0),
('2023-06-28', 4, 3, 3, 8, 220.00, 0.0),
-- Julho 2023
('2023-07-04', 1, 11,1, 2, 4200.00, 5.0),
('2023-07-06', 15,3, 3, 2, 1400.00, 0.0),
('2023-07-08', 5, 12,2, 6, 380.00, 0.0),
('2023-07-10', 13,13,5, 30,120.00, 0.0),
('2023-07-12', 3, 2, 1, 6, 450.00, 0.0),
('2023-07-15', 9, 6, 4, 2, 1600.00, 2.0),
('2023-07-18', 11,8, 6, 4, 950.00, 2.0),
('2023-07-20', 6, 9, 2, 1, 1800.00, 3.0),
('2023-07-22', 12,2, 1, 20,180.00, 0.0),
('2023-07-25', 2, 11,1, 2, 2800.00, 5.0),
-- Agosto 2023
('2023-08-03', 8, 9, 1, 2,12000.00, 8.0),
('2023-08-06', 1, 2, 1, 3, 4200.00, 5.0),
('2023-08-08', 7, 11,2, 1, 2400.00, 4.0),
('2023-08-10', 6, 7, 5, 2, 1800.00, 3.0),
('2023-08-12', 3, 1, 1, 12,450.00, 0.0),
('2023-08-15', 14,4, 2, 2, 1900.00, 0.0),
('2023-08-18', 10,8, 6, 8, 680.00, 2.0),
('2023-08-20', 12,5, 3, 20,180.00, 0.0),
('2023-08-22', 5, 12,2, 5, 380.00, 0.0),
('2023-08-25', 4, 15,5, 10,220.00, 0.0),
('2023-08-28', 13,13,5, 20,120.00, 0.0),
-- Setembro 2023
('2023-09-02', 1, 2, 1, 2, 4200.00, 5.0),
('2023-09-05', 2, 4, 2, 2, 2800.00, 5.0),
('2023-09-08', 9, 6, 4, 3, 1600.00, 2.0),
('2023-09-10', 6, 11,2, 2, 1800.00, 3.0),
('2023-09-12', 15,3, 3, 2, 1400.00, 0.0),
('2023-09-15', 3, 2, 1, 8, 450.00, 0.0),
('2023-09-18', 7, 7, 5, 2, 2400.00, 4.0),
('2023-09-20', 11,8, 6, 5, 950.00, 2.0),
('2023-09-22', 12,2, 1, 20,180.00, 0.0),
('2023-09-25', 8, 9, 1, 1,12000.00,10.0),
('2023-09-28', 10,8, 6, 4, 680.00, 2.0),
-- Outubro 2023
('2023-10-04', 1, 11,1, 3, 4200.00, 5.0),
('2023-10-06', 5, 12,2, 8, 380.00, 0.0),
('2023-10-08', 13,13,5, 30,120.00, 0.0),
('2023-10-10', 6, 9, 2, 3, 1800.00, 3.0),
('2023-10-12', 3, 2, 1, 10,450.00, 0.0),
('2023-10-15', 14,4, 2, 2, 1900.00, 0.0),
('2023-10-18', 9, 6, 4, 2, 1600.00, 2.0),
('2023-10-20', 2, 11,1, 2, 2800.00, 5.0),
('2023-10-22', 12,5, 3, 15,180.00, 0.0),
('2023-10-25', 7, 7, 5, 1, 2400.00, 4.0),
('2023-10-28', 4, 3, 3, 10,220.00, 0.0),
-- Novembro 2023
('2023-11-03', 8, 9, 1, 2,12000.00, 8.0),
('2023-11-05', 1, 2, 1, 4, 4200.00, 5.0),
('2023-11-08', 6, 11,2, 3, 1800.00, 3.0),
('2023-11-10', 2, 4, 2, 2, 2800.00, 5.0),
('2023-11-12', 15,3, 3, 3, 1400.00, 0.0),
('2023-11-15', 3, 2, 1, 15,450.00, 0.0),
('2023-11-18', 10,8, 6, 10,680.00, 2.0),
('2023-11-20', 11,8, 6, 5, 950.00, 2.0),
('2023-11-22', 12,2, 1, 25,180.00, 0.0),
('2023-11-25', 7, 7, 5, 2, 2400.00, 4.0),
('2023-11-28', 5, 12,2, 8, 380.00, 0.0),
('2023-11-30', 14,4, 2, 3, 1900.00, 0.0),
-- Dezembro 2023 (pico de vendas)
('2023-12-02', 1, 2, 1, 5, 4200.00, 7.0),
('2023-12-04', 8, 9, 1, 2,12000.00,10.0),
('2023-12-06', 2, 11,1, 3, 2800.00, 5.0),
('2023-12-08', 6, 7, 5, 3, 1800.00, 3.0),
('2023-12-10', 7, 11,2, 2, 2400.00, 4.0),
('2023-12-12', 3, 2, 1, 20,450.00, 0.0),
('2023-12-14', 9, 6, 4, 4, 1600.00, 2.0),
('2023-12-16', 15,3, 3, 4, 1400.00, 0.0),
('2023-12-18', 14,4, 2, 4, 1900.00, 0.0),
('2023-12-19', 12,2, 1, 30,180.00, 0.0),
('2023-12-20', 5, 12,2, 10,380.00, 0.0),
('2023-12-21', 10,8, 6, 12,680.00, 2.0),
('2023-12-22', 13,13,5, 40,120.00, 0.0),
('2023-12-26', 1, 11,1, 3, 4200.00, 5.0),
('2023-12-28', 4, 15,5, 15,220.00, 0.0);

-- 2024 — Janeiro a Dezembro (crescimento ~15%)
INSERT INTO fato_vendas (data_venda, id_produto, id_cliente, id_vendedor, quantidade, preco_venda, desconto_pct) VALUES
-- Janeiro 2024
('2024-01-05', 1, 2, 1, 2, 4350.00, 5.0),
('2024-01-08', 3, 1, 1, 6, 460.00, 0.0),
('2024-01-10', 12,2, 2, 12,185.00, 0.0),
('2024-01-12', 6, 11,2, 2, 1850.00, 3.0),
('2024-01-15', 4, 3, 3, 5, 230.00, 0.0),
('2024-01-18', 10,8, 6, 4, 700.00, 2.0),
('2024-01-20', 14,4, 2, 2, 1950.00, 0.0),
('2024-01-22', 8, 9, 1, 1,12500.00, 8.0),
('2024-01-25', 13,5, 3, 10,125.00, 0.0),
('2024-01-28', 2, 11,1, 2, 2900.00, 5.0),
('2024-01-30', 7, 7, 5, 1, 2500.00, 4.0),
-- Fevereiro 2024
('2024-02-03', 1, 2, 1, 2, 4350.00, 5.0),
('2024-02-06', 5, 3, 3, 4, 390.00, 0.0),
('2024-02-08', 7, 11,2, 1, 2500.00, 4.0),
('2024-02-10', 12,14,4, 18,185.00, 0.0),
('2024-02-13', 9, 6, 4, 2, 1650.00, 2.0),
('2024-02-15', 3, 2, 1, 10,460.00, 0.0),
('2024-02-18', 10,9, 6, 6, 700.00, 3.0),
('2024-02-20', 4, 5, 3, 7, 230.00, 0.0),
('2024-02-22', 13,13,5, 22,125.00, 0.0),
('2024-02-25', 11,8, 6, 3, 980.00, 2.0),
('2024-02-28', 15,3, 8, 2, 1450.00, 0.0),
-- Março 2024
('2024-03-02', 8, 9, 1, 2,12500.00,10.0),
('2024-03-05', 1, 2, 1, 4, 4350.00, 7.0),
('2024-03-08', 6, 11,2, 3, 1850.00, 3.0),
('2024-03-10', 2, 4, 2, 2, 2900.00, 5.0),
('2024-03-12', 15,3, 3, 2, 1450.00, 0.0),
('2024-03-15', 12,2, 1, 22,185.00, 0.0),
('2024-03-18', 5, 12,2, 5, 390.00, 0.0),
('2024-03-20', 3, 1, 1, 12,460.00, 0.0),
('2024-03-22', 7, 7, 5, 2, 2500.00, 4.0),
('2024-03-25', 4, 15,5, 10,230.00, 0.0),
('2024-03-28', 10,8, 6, 5, 700.00, 2.0),
('2024-03-30', 14,4, 8, 2, 1950.00, 0.0),
-- Abril 2024
('2024-04-04', 1, 11,1, 3, 4350.00, 5.0),
('2024-04-06', 9, 6, 4, 3, 1650.00, 2.0),
('2024-04-08', 13,13,5, 28,125.00, 0.0),
('2024-04-10', 3, 2, 1, 8, 460.00, 0.0),
('2024-04-12', 6, 9, 2, 3, 1850.00, 3.0),
('2024-04-15', 14,4, 2, 2, 1950.00, 0.0),
('2024-04-18', 12,5, 3, 18,185.00, 0.0),
('2024-04-20', 2, 11,1, 2, 2900.00, 5.0),
('2024-04-22', 11,8, 6, 4, 980.00, 2.0),
('2024-04-25', 4, 3, 3, 6, 230.00, 0.0),
('2024-04-28', 7, 7, 5, 2, 2500.00, 4.0),
-- Maio 2024
('2024-05-03', 8, 9, 1, 2,12500.00, 8.0),
('2024-05-06', 1, 2, 1, 3, 4350.00, 5.0),
('2024-05-08', 7, 11,2, 2, 2500.00, 4.0),
('2024-05-10', 15,3, 3, 2, 1450.00, 0.0),
('2024-05-12', 5, 12,2, 7, 390.00, 0.0),
('2024-05-15', 12,2, 1, 22,185.00, 0.0),
('2024-05-18', 10,8, 6, 7, 700.00, 2.0),
('2024-05-20', 3, 1, 1, 10,460.00, 0.0),
('2024-05-22', 6, 7, 5, 2, 1850.00, 3.0),
('2024-05-25', 13,15,5, 22,125.00, 0.0),
('2024-05-28', 9, 6, 4, 3, 1650.00, 2.0),
-- Junho 2024
('2024-06-02', 1, 2, 1, 3, 4350.00, 5.0),
('2024-06-05', 9, 6, 4, 3, 1650.00, 2.0),
('2024-06-08', 2, 4, 2, 2, 2900.00, 5.0),
('2024-06-10', 8, 9, 1, 1,12500.00,10.0),
('2024-06-12', 6, 11,2, 3, 1850.00, 3.0),
('2024-06-15', 3, 2, 1, 12,460.00, 0.0),
('2024-06-18', 14,4, 2, 2, 1950.00, 0.0),
('2024-06-20', 12,5, 3, 18,185.00, 0.0),
('2024-06-22', 10,8, 6, 6, 700.00, 2.0),
('2024-06-25', 7, 7, 5, 2, 2500.00, 4.0),
('2024-06-28', 4, 3, 3, 10,230.00, 0.0),
-- Julho 2024
('2024-07-04', 1, 11,1, 3, 4350.00, 5.0),
('2024-07-06', 15,3, 3, 2, 1450.00, 0.0),
('2024-07-08', 5, 12,2, 8, 390.00, 0.0),
('2024-07-10', 13,13,5, 32,125.00, 0.0),
('2024-07-12', 3, 2, 1, 8, 460.00, 0.0),
('2024-07-15', 9, 6, 4, 3, 1650.00, 2.0),
('2024-07-18', 11,8, 6, 5, 980.00, 2.0),
('2024-07-20', 6, 9, 2, 2, 1850.00, 3.0),
('2024-07-22', 12,2, 1, 22,185.00, 0.0),
('2024-07-25', 2, 11,1, 2, 2900.00, 5.0),
('2024-07-28', 8, 9, 1, 1,12500.00, 8.0),
-- Agosto 2024
('2024-08-03', 8, 9, 1, 2,12500.00, 8.0),
('2024-08-06', 1, 2, 1, 4, 4350.00, 5.0),
('2024-08-08', 7, 11,2, 2, 2500.00, 4.0),
('2024-08-10', 6, 7, 5, 2, 1850.00, 3.0),
('2024-08-12', 3, 1, 1, 14,460.00, 0.0),
('2024-08-15', 14,4, 2, 2, 1950.00, 0.0),
('2024-08-18', 10,8, 6, 9, 700.00, 2.0),
('2024-08-20', 12,5, 3, 22,185.00, 0.0),
('2024-08-22', 5, 12,2, 7, 390.00, 0.0),
('2024-08-25', 4, 15,5, 12,230.00, 0.0),
('2024-08-28', 13,13,5, 22,125.00, 0.0),
('2024-08-30', 9, 6, 8, 3, 1650.00, 2.0),
-- Setembro 2024
('2024-09-02', 1, 2, 1, 3, 4350.00, 5.0),
('2024-09-05', 2, 4, 2, 2, 2900.00, 5.0),
('2024-09-08', 9, 6, 4, 3, 1650.00, 2.0),
('2024-09-10', 6, 11,2, 3, 1850.00, 3.0),
('2024-09-12', 15,3, 3, 2, 1450.00, 0.0),
('2024-09-15', 3, 2, 1, 10,460.00, 0.0),
('2024-09-18', 7, 7, 5, 2, 2500.00, 4.0),
('2024-09-20', 11,8, 6, 6, 980.00, 2.0),
('2024-09-22', 12,2, 1, 22,185.00, 0.0),
('2024-09-25', 8, 9, 1, 2,12500.00,10.0),
('2024-09-28', 10,8, 6, 5, 700.00, 2.0),
('2024-09-30', 14,4, 8, 2, 1950.00, 0.0),
-- Outubro 2024
('2024-10-04', 1, 11,1, 4, 4350.00, 5.0),
('2024-10-06', 5, 12,2, 9, 390.00, 0.0),
('2024-10-08', 13,13,5, 32,125.00, 0.0),
('2024-10-10', 6, 9, 2, 3, 1850.00, 3.0),
('2024-10-12', 3, 2, 1, 12,460.00, 0.0),
('2024-10-15', 14,4, 2, 3, 1950.00, 0.0),
('2024-10-18', 9, 6, 4, 3, 1650.00, 2.0),
('2024-10-20', 2, 11,1, 2, 2900.00, 5.0),
('2024-10-22', 12,5, 3, 18,185.00, 0.0),
('2024-10-25', 7, 7, 5, 2, 2500.00, 4.0),
('2024-10-28', 4, 3, 3, 12,230.00, 0.0),
('2024-10-30', 8, 9, 1, 1,12500.00, 8.0),
-- Novembro 2024
('2024-11-03', 8, 9, 1, 2,12500.00, 8.0),
('2024-11-05', 1, 2, 1, 5, 4350.00, 5.0),
('2024-11-08', 6, 11,2, 4, 1850.00, 3.0),
('2024-11-10', 2, 4, 2, 3, 2900.00, 5.0),
('2024-11-12', 15,3, 3, 3, 1450.00, 0.0),
('2024-11-15', 3, 2, 1, 18,460.00, 0.0),
('2024-11-18', 10,8, 6, 12,700.00, 2.0),
('2024-11-20', 11,8, 6, 6, 980.00, 2.0),
('2024-11-22', 12,2, 1, 28,185.00, 0.0),
('2024-11-25', 7, 7, 5, 3, 2500.00, 4.0),
('2024-11-28', 5, 12,2, 10,390.00, 0.0),
('2024-11-30', 14,4, 2, 4, 1950.00, 0.0),
-- Dezembro 2024 (pico — acima de 2023)
('2024-12-02', 1, 2, 1, 6, 4350.00, 7.0),
('2024-12-04', 8, 9, 1, 3,12500.00,10.0),
('2024-12-06', 2, 11,1, 4, 2900.00, 5.0),
('2024-12-08', 6, 7, 5, 4, 1850.00, 3.0),
('2024-12-10', 7, 11,2, 3, 2500.00, 4.0),
('2024-12-12', 3, 2, 1, 25,460.00, 0.0),
('2024-12-14', 9, 6, 4, 5, 1650.00, 2.0),
('2024-12-16', 15,3, 3, 5, 1450.00, 0.0),
('2024-12-18', 14,4, 2, 5, 1950.00, 0.0),
('2024-12-19', 12,2, 1, 35,185.00, 0.0),
('2024-12-20', 5, 12,2, 12,390.00, 0.0),
('2024-12-21', 10,8, 6, 15,700.00, 2.0),
('2024-12-22', 13,13,5, 45,125.00, 0.0),
('2024-12-26', 1, 11,1, 4, 4350.00, 5.0),
('2024-12-28', 4, 15,5, 18,230.00, 0.0),
('2024-12-30', 8, 9, 8, 1,12500.00, 8.0);
GO

-- 5. VIEWS ANALÍTICAS
-- ============================================================

-- VIEW 1: Visão Geral de Vendas por Mês com Variação YoY
-- Técnica: CTE + LAG (window function)
-- ============================================================
IF OBJECT_ID('vw_vendas_mensal_yoy', 'V') IS NOT NULL DROP VIEW vw_vendas_mensal_yoy;
GO
CREATE VIEW vw_vendas_mensal_yoy AS
WITH vendas_mensais AS (
    SELECT
        YEAR(data_venda)                        AS ano,
        MONTH(data_venda)                       AS mes,
        FORMAT(data_venda, 'MMM/yyyy')          AS periodo,
        COUNT(DISTINCT id_venda)                AS qtd_pedidos,
        SUM(receita_liquida)                    AS receita_total,
        AVG(receita_liquida / quantidade)       AS ticket_medio,
        COUNT(DISTINCT id_cliente)              AS clientes_ativos
    FROM fato_vendas
    GROUP BY
        YEAR(data_venda),
        MONTH(data_venda),
        FORMAT(data_venda, 'MMM/yyyy')
)
SELECT
    ano,
    mes,
    periodo,
    qtd_pedidos,
    ROUND(receita_total, 2)             AS receita_total,
    ROUND(ticket_medio, 2)              AS ticket_medio,
    clientes_ativos,
    LAG(receita_total, 12) OVER (
        ORDER BY ano, mes
    )                                   AS receita_ano_anterior,
    CASE
        WHEN LAG(receita_total, 12) OVER (ORDER BY ano, mes) IS NULL THEN NULL
        ELSE ROUND(
            (receita_total - LAG(receita_total, 12) OVER (ORDER BY ano, mes))
            / LAG(receita_total, 12) OVER (ORDER BY ano, mes) * 100, 2)
    END                                 AS variacao_yoy_pct
FROM vendas_mensais;
GO

-- VIEW 2: Ranking de Produtos por Receita com Classificação ABC
-- Técnica: CTE + RANK() + Classificação ABC com SUM acumulado
-- ============================================================
IF OBJECT_ID('vw_ranking_produtos_abc', 'V') IS NOT NULL DROP VIEW vw_ranking_produtos_abc;
GO
CREATE VIEW vw_ranking_produtos_abc AS
WITH receita_produto AS (
    SELECT
        p.id_produto,
        p.produto,
        p.categoria,
        p.preco_unitario,
        SUM(f.quantidade)               AS qtd_vendida,
        SUM(f.receita_liquida)          AS receita_total,
        COUNT(DISTINCT f.id_venda)      AS qtd_pedidos,
        AVG(f.desconto_pct)             AS desconto_medio_pct
    FROM fato_vendas f
    INNER JOIN dim_produtos p ON f.id_produto = p.id_produto
    GROUP BY p.id_produto, p.produto, p.categoria, p.preco_unitario
),
total_geral AS (
    SELECT SUM(receita_total) AS receita_geral FROM receita_produto
),
acumulado AS (
    SELECT
        r.*,
        t.receita_geral,
        RANK() OVER (ORDER BY r.receita_total DESC)     AS ranking,
        ROUND(r.receita_total / t.receita_geral * 100, 2) AS participacao_pct,
        SUM(r.receita_total) OVER (
            ORDER BY r.receita_total DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / t.receita_geral * 100                       AS participacao_acumulada_pct
    FROM receita_produto r
    CROSS JOIN total_geral t
)
SELECT
    ranking,
    id_produto,
    produto,
    categoria,
    preco_unitario,
    qtd_vendida,
    ROUND(receita_total, 2)             AS receita_total,
    qtd_pedidos,
    ROUND(desconto_medio_pct, 1)        AS desconto_medio_pct,
    ROUND(participacao_pct, 2)          AS participacao_pct,
    ROUND(participacao_acumulada_pct, 2) AS participacao_acumulada_pct,
    CASE
        WHEN participacao_acumulada_pct <= 70 THEN 'A'
        WHEN participacao_acumulada_pct <= 90 THEN 'B'
        ELSE 'C'
    END                                 AS curva_abc
FROM acumulado;
GO

-- VIEW 3: Performance de Vendedores com Meta vs Realizado
-- Técnica: CTE + RANK() por receita + % atingimento de meta
-- ============================================================
IF OBJECT_ID('vw_performance_vendedores', 'V') IS NOT NULL DROP VIEW vw_performance_vendedores;
GO
CREATE VIEW vw_performance_vendedores AS
WITH vendas_vendedor AS (
    SELECT
        v.id_vendedor,
        v.nome,
        v.cargo,
        v.meta_anual,
        r.regiao,
        r.estado,
        YEAR(f.data_venda)              AS ano,
        SUM(f.receita_liquida)          AS receita_realizada,
        COUNT(DISTINCT f.id_venda)      AS qtd_pedidos,
        COUNT(DISTINCT f.id_cliente)    AS clientes_atendidos,
        AVG(f.desconto_pct)             AS desconto_medio_pct
    FROM fato_vendas f
    INNER JOIN dim_vendedores v ON f.id_vendedor = v.id_vendedor
    INNER JOIN dim_regioes r    ON v.id_regiao   = r.id_regiao
    GROUP BY
        v.id_vendedor, v.nome, v.cargo, v.meta_anual,
        r.regiao, r.estado, YEAR(f.data_venda)
)
SELECT
    id_vendedor,
    nome,
    cargo,
    regiao,
    estado,
    ano,
    meta_anual,
    ROUND(receita_realizada, 2)         AS receita_realizada,
    ROUND(receita_realizada / meta_anual * 100, 1) AS atingimento_meta_pct,
    CASE
        WHEN receita_realizada >= meta_anual             THEN 'Meta Atingida'
        WHEN receita_realizada >= meta_anual * 0.85      THEN 'Próximo da Meta'
        ELSE 'Abaixo da Meta'
    END                                 AS status_meta,
    qtd_pedidos,
    clientes_atendidos,
    ROUND(desconto_medio_pct, 1)        AS desconto_medio_pct,
    RANK() OVER (
        PARTITION BY ano
        ORDER BY receita_realizada DESC
    )                                   AS ranking_ano
FROM vendas_vendedor;
GO

-- VIEW 4: Vendas por Categoria com Running Total Mensal
-- Técnica: CTE + SUM() OVER() para acumulado corrente
-- ============================================================
IF OBJECT_ID('vw_vendas_categoria_acumulado', 'V') IS NOT NULL DROP VIEW vw_vendas_categoria_acumulado;
GO
CREATE VIEW vw_vendas_categoria_acumulado AS
WITH vendas_cat AS (
    SELECT
        YEAR(f.data_venda)              AS ano,
        MONTH(f.data_venda)             AS mes,
        p.categoria,
        SUM(f.receita_liquida)          AS receita_mes
    FROM fato_vendas f
    INNER JOIN dim_produtos p ON f.id_produto = p.id_produto
    GROUP BY
        YEAR(f.data_venda), MONTH(f.data_venda), p.categoria
)
SELECT
    ano,
    mes,
    categoria,
    ROUND(receita_mes, 2)               AS receita_mes,
    ROUND(SUM(receita_mes) OVER (
        PARTITION BY ano, categoria
        ORDER BY mes
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2)                               AS receita_acumulada_ano
FROM vendas_cat;
GO

-- VIEW 5: Análise de Clientes (RFM simplificado)
-- Técnica: CTE + DENSE_RANK() por recência e valor
-- ============================================================
IF OBJECT_ID('vw_analise_clientes', 'V') IS NOT NULL DROP VIEW vw_analise_clientes;
GO
CREATE VIEW vw_analise_clientes AS
WITH base_clientes AS (
    SELECT
        c.id_cliente,
        c.razao_social,
        c.segmento,
        r.regiao,
        COUNT(DISTINCT f.id_venda)      AS frequencia,
        SUM(f.receita_liquida)          AS valor_total,
        MAX(f.data_venda)               AS ultima_compra,
        MIN(f.data_venda)               AS primeira_compra,
        DATEDIFF(DAY, MAX(f.data_venda), '2024-12-31') AS dias_desde_ultima_compra
    FROM fato_vendas f
    INNER JOIN dim_clientes c ON f.id_cliente = c.id_cliente
    INNER JOIN dim_regioes r  ON c.id_regiao  = r.id_regiao
    GROUP BY c.id_cliente, c.razao_social, c.segmento, r.regiao
)
SELECT
    id_cliente,
    razao_social,
    segmento,
    regiao,
    frequencia,
    ROUND(valor_total, 2)               AS valor_total,
    ultima_compra,
    primeira_compra,
    dias_desde_ultima_compra,
    DENSE_RANK() OVER (ORDER BY valor_total DESC)        AS ranking_valor,
    DENSE_RANK() OVER (ORDER BY frequencia DESC)         AS ranking_frequencia,
    CASE
        WHEN dias_desde_ultima_compra <= 90  THEN 'Ativo'
        WHEN dias_desde_ultima_compra <= 180 THEN 'Em risco'
        ELSE 'Inativo'
    END                                 AS status_cliente
FROM base_clientes;
GO

-- VIEW 6: KPIs Gerais Consolidados por Ano
-- Técnica: CTE com múltiplos agregados + crescimento YoY
-- ============================================================
IF OBJECT_ID('vw_kpis_anuais', 'V') IS NOT NULL DROP VIEW vw_kpis_anuais;
GO
CREATE VIEW vw_kpis_anuais AS
WITH kpis AS (
    SELECT
        YEAR(data_venda)                AS ano,
        SUM(receita_liquida)            AS receita_total,
        SUM(receita_bruta)              AS receita_bruta_total,
        COUNT(DISTINCT id_venda)        AS qtd_pedidos,
        COUNT(DISTINCT id_cliente)      AS clientes_ativos,
        COUNT(DISTINCT id_produto)      AS produtos_vendidos,
        COUNT(DISTINCT id_vendedor)     AS vendedores_ativos,
        AVG(desconto_pct)               AS desconto_medio_pct,
        SUM(receita_liquida) / COUNT(DISTINCT id_venda) AS ticket_medio
    FROM fato_vendas
    GROUP BY YEAR(data_venda)
)
SELECT
    ano,
    ROUND(receita_total, 2)             AS receita_total,
    ROUND(receita_bruta_total, 2)       AS receita_bruta_total,
    ROUND((1 - receita_total/receita_bruta_total)*100, 2) AS desconto_total_pct,
    qtd_pedidos,
    clientes_ativos,
    produtos_vendidos,
    vendedores_ativos,
    ROUND(desconto_medio_pct, 1)        AS desconto_medio_pct,
    ROUND(ticket_medio, 2)              AS ticket_medio,
    LAG(receita_total) OVER (ORDER BY ano) AS receita_ano_anterior,
    CASE
        WHEN LAG(receita_total) OVER (ORDER BY ano) IS NULL THEN NULL
        ELSE ROUND(
            (receita_total - LAG(receita_total) OVER (ORDER BY ano))
            / LAG(receita_total) OVER (ORDER BY ano) * 100, 2)
    END                                 AS crescimento_yoy_pct
FROM kpis;
GO

-- ============================================================
-- VERIFICAÇÃO FINAL
-- ============================================================
SELECT 'dim_regioes'   AS tabela, COUNT(*) AS registros FROM dim_regioes   UNION ALL
SELECT 'dim_vendedores',          COUNT(*)              FROM dim_vendedores UNION ALL
SELECT 'dim_produtos',            COUNT(*)              FROM dim_produtos   UNION ALL
SELECT 'dim_clientes',            COUNT(*)              FROM dim_clientes   UNION ALL
SELECT 'fato_vendas',             COUNT(*)              FROM fato_vendas;

SELECT * FROM vw_kpis_anuais;
SELECT * FROM vw_ranking_produtos_abc ORDER BY ranking;
SELECT * FROM vw_performance_vendedores WHERE ano = 2024 ORDER BY ranking_ano;
GO
