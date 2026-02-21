-----------------------------------------------------
-- Estudo de Caso: Cooperativa Agrícola 
-- Tecnologias: SQL, CTEs, Window Functions, Joins
-----------------------------------------------------


-- # Desafio 1: O Catálogo de Culturas
-- Missão: Selecionar apenas os nomes das culturas disponíveis no sistema para um relatório simples.
SELECT nome_cultura FROM culturas;


-- # Desafio 2: Focando no Milho (Filtros e Ordenação)
-- Missão: A equipe de logística precisa de uma lista de todas as entregas de 'Milho',
-- ordenadas da carga mais pesada para a mais leve, para priorizar o armazenamento.
SELECT * FROM entregas_safra 
WHERE id_cultura = 2 
ORDER BY peso_kg DESC;


-- # Desafio 3: O Balanço Total (Agregação Simples)
-- Missão: A diretoria quer o número total, absoluto, de quilogramas de grãos que entraram no silo até hoje.
SELECT sum(peso_kg) as total_safra FROM entregas_safra;


-- # Desafio 4: Controle de Qualidade (CASE WHEN)
-- Missão: Classificar as entregas de milho baseadas na taxa de umidade.
-- Regra: Se for Nulo -> 'Averiguar'; Se for > 14.0 -> 'Desconto Aplicado'; Senão -> 'Padrão Ideal'.
SELECT 
    es.id_entrega,
    es.peso_kg,
    CASE
        WHEN es.taxa_umidade IS NULL THEN 'Averiguar'
        WHEN es.taxa_umidade > 14.0 THEN 'Desconto Aplicado'
        ELSE 'Padrão Ideal'
    END AS padrao_qualidade
FROM culturas c 
JOIN entregas_safra es ON c.id_cultura = es.id_cultura
WHERE c.nome_cultura = 'Milho'
GROUP BY es.id_entrega;


-- # Desafio 5: O Top 1 Produtor por Cultura (Ranking com CTE)
-- Missão: Identificar quem foi o "Campeão da Safra" (maior volume total entregue) para cada cultura específica.
WITH soma_por_produtor AS (
    SELECT 
        c.nome, 
        ct.nome_cultura, 
        SUM(es.peso_kg) as peso_total_coop
    FROM cooperados c 
    JOIN entregas_safra es ON c.id_cooperado = es.id_cooperado
    JOIN culturas ct ON es.id_cultura = ct.id_cultura
    WHERE es.peso_kg > 0 
    GROUP BY c.id_cooperado, ct.nome_cultura
),
rank_final AS (
    SELECT 
        nome, 
        nome_cultura, 
        peso_total_coop,
        ROW_NUMBER() OVER (PARTITION BY nome_cultura ORDER BY peso_total_coop DESC) as ranqueado
    FROM soma_por_produtor
)
SELECT nome, nome_cultura, peso_total_coop
FROM rank_final
WHERE ranqueado = 1;


-- # Desafio 6: Produtores "Acima da Média" (Subquery no WHERE)
-- Missão: Listar os cooperados cujo volume total de entrega de 'Trigo' superou a média geral de entregas de trigo.
WITH media_total AS (
    SELECT AVG(peso_kg) as mediatotal 
    FROM entregas_safra es 
    JOIN culturas c ON es.id_cultura = c.id_cultura
    WHERE c.nome_cultura = 'Trigo' AND es.peso_kg > 0
),
somacooperados AS (
    SELECT c.nome, SUM(peso_kg) as somatotal 
    FROM entregas_safra es
    JOIN cooperados c ON es.id_cooperado = c.id_cooperado
    JOIN culturas ct ON es.id_cultura = ct.id_cultura
    WHERE es.peso_kg > 0 AND ct.nome_cultura = 'Trigo'
    GROUP BY c.id_cooperado, c.nome
)
SELECT nome, somatotal
FROM somacooperados
WHERE somatotal > (SELECT mediatotal FROM media_total);


-- # Desafio 7: O "Gap" de Pagamento (Manipulação de Datas)
-- Missão: Calcular o tempo (em dias) entre a entrada do grão no silo e o efetivo pagamento ao cooperado.
SELECT 
    es.id_entrega,
    c.nome,
    es.data_recebimento,
    f.data_pagamento,
    julianday(f.data_pagamento) - julianday(es.data_recebimento) as dias_para_pagar
FROM entregas_safra es
JOIN cooperados c ON es.id_cooperado = c.id_cooperado
JOIN faturamento f ON es.id_entrega = f.id_entrega;


-- # Desafio 8: Filtro de Inatividade (LEFT JOIN + NULL)
-- Missão: Identificar cooperados cadastrados que nunca realizaram nenhuma entrega (para ações de marketing).
SELECT c.nome 
FROM cooperados c
LEFT JOIN entregas_safra es ON c.id_cooperado = es.id_cooperado
WHERE es.id_cooperado IS NULL; 


-- # Desafio 9: Rentabilidade Média por Cultura
-- Missão: Calcular o valor médio pago por quilo para cada tipo de grão, considerando apenas entregas já faturadas.
SELECT 
    c.nome_cultura,
    AVG(f.valor_pago_por_kg) as media_valor_kg
FROM culturas c
JOIN entregas_safra es ON c.id_cultura = es.id_cultura
JOIN faturamento f ON es.id_entrega = f.id_entrega
WHERE f.valor_pago_por_kg IS NOT NULL AND f.valor_pago_por_kg > 0
GROUP BY c.nome_cultura, c.id_cultura;


-- # Desafio 10: O Acumulado da Safra (Running Total / Window Function)
-- Missão: Criar um relatório cronológico mostrando o peso da entrega do dia e o total acumulado da safra até aquele momento.
SELECT 
    data_recebimento, 
    peso_kg,
    SUM(peso_kg) OVER (ORDER BY data_recebimento ASC) as peso_acumulado
FROM entregas_safra
WHERE peso_kg > 0 AND peso_kg IS NOT NULL
ORDER BY data_recebimento ASC;


-- # Bônus 1: Alerta de Umidade (Relatório Consolidado)
-- Missão: Notificar cooperados que entregaram Soja com média de umidade acima do limite de 13.5%.
SELECT 
    c.nome,
    ct.nome_cultura,
    SUM(es.peso_kg) as peso_total,
    CASE
        WHEN AVG(es.taxa_umidade) <= 13.5 THEN 'OK'
        ELSE 'ACIMA DO LIMITE'
    END as status_umidade
FROM cooperados c
JOIN entregas_safra es ON c.id_cooperado = es.id_cooperado
JOIN culturas ct ON es.id_cultura = ct.id_cultura
WHERE ct.nome_cultura = 'Soja' 
  AND es.peso_kg > 0 
GROUP BY c.id_cooperado, c.nome, ct.nome_cultura
ORDER BY peso_total DESC;


-- # Bônus 2: Ranking de Faturamento Mensal (Extração de Data e CTE)
-- Missão: Rankear os cooperados que mais faturaram (peso * valor) especificamente no mês de Fevereiro de 2025.
WITH totalcoop AS (
    SELECT 
        c.id_cooperado,
        c.nome,
        SUM(es.peso_kg * f.valor_pago_por_kg) as faturamento_total
    FROM cooperados c 
    JOIN entregas_safra es ON c.id_cooperado = es.id_cooperado
    JOIN faturamento f ON es.id_entrega = f.id_entrega
    WHERE substr(f.data_pagamento, 1, 7) = '2025-02'
    GROUP BY c.id_cooperado, c.nome
)
SELECT 
    nome,
    faturamento_total,
    ROW_NUMBER() OVER (ORDER BY faturamento_total DESC) as ranking_fevereiro
FROM totalcoop;

