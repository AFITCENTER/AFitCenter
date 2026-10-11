-- =====================================================================
-- AFitCenter — catálogos iniciais do sistema
-- =====================================================================

-- ---------------------------------------------------------------------
-- Métricas: cobrem todos os campos do laudo Relaxmedic + antropometria + exames
-- ---------------------------------------------------------------------
INSERT INTO metrica (codigo, nome, unidade, categoria, casas_decimais) VALUES
  -- Básicas (vêm das colunas de avaliacao; não inserir em avaliacao_resultado)
  ('PESO',                     'Peso',                              'kg',     'BASICA',       1),
  ('ALTURA',                   'Altura',                            'cm',     'BASICA',       1),
  ('IMC',                      'IMC',                               'kg/m²',  'BASICA',       1),
  -- Composição corporal
  ('GORDURA_KG',               'Massa gorda',                       'kg',     'COMPOSICAO',   1),
  ('GORDURA_PCT',              'Percentual de gordura',             '%',      'COMPOSICAO',   1),
  ('MASSA_MUSCULAR_KG',        'Massa muscular',                    'kg',     'COMPOSICAO',   1),
  ('MUSCULO_ESQUELETICO_KG',   'Massa muscular esquelética',        'kg',     'COMPOSICAO',   1),
  ('MASSA_LIVRE_GORDURA_KG',   'Massa livre de gordura',            'kg',     'COMPOSICAO',   1),
  ('AGUA_CORPORAL_KG',         'Água corporal total',               'kg',     'COMPOSICAO',   1),
  ('PROTEINA_KG',              'Proteína',                          'kg',     'COMPOSICAO',   1),
  ('MINERAIS_KG',              'Minerais (sal inorgânico)',         'kg',     'COMPOSICAO',   1),
  ('GORDURA_SUBCUTANEA_PCT',   'Gordura subcutânea',                '%',      'COMPOSICAO',   1),
  ('GORDURA_VISCERAL_NIVEL',   'Gordura visceral',                  'nível',  'COMPOSICAO',   0),
  -- Índices calculados pelo aparelho
  ('TMB_KCAL',                 'Taxa metabólica basal',             'kcal',   'INDICE',       0),
  ('SMI',                      'Índice de massa muscular esquelética (SMI)', 'kg/m²', 'INDICE', 1),
  ('IDADE_CORPORAL',           'Idade corporal',                    'anos',   'INDICE',       0),
  ('RCQ',                      'Relação cintura-quadril',           'razão',  'INDICE',       2),
  ('PONTUACAO_CORPORAL',       'Pontuação corporal',                'pontos', 'INDICE',       0),
  ('ANGULO_FASE',              'Ângulo de fase',                    '°',      'INDICE',       1),
  ('PESO_ALVO_KG',             'Peso alvo sugerido pelo aparelho',  'kg',     'INDICE',       1),
  ('CONTROLE_PESO_KG',         'Controle de peso',                  'kg',     'INDICE',       1),
  ('CONTROLE_GORDURA_KG',      'Controle de gordura',               'kg',     'INDICE',       1),
  ('CONTROLE_MUSCULAR_KG',     'Controle muscular',                 'kg',     'INDICE',       1),
  -- Segmentares (usar com regiao_id)
  ('MASSA_MAGRA_SEG_KG',       'Massa magra segmentar',             'kg',     'SEGMENTAR',    1),
  ('MASSA_MAGRA_SEG_PCT_REF',  'Massa magra segmentar (% do padrão)', '%',    'SEGMENTAR',    1),
  ('GORDURA_SEG_KG',           'Gordura segmentar',                 'kg',     'SEGMENTAR',    1),
  ('GORDURA_SEG_PCT_REF',      'Gordura segmentar (% do padrão)',   '%',      'SEGMENTAR',    1),
  -- Impedância bruta por frequência (usar com regiao_id)
  ('IMPEDANCIA_5KHZ',          'Impedância 5 kHz',                  'Ω',      'IMPEDANCIA',   1),
  ('IMPEDANCIA_20KHZ',         'Impedância 20 kHz',                 'Ω',      'IMPEDANCIA',   1),
  ('IMPEDANCIA_50KHZ',         'Impedância 50 kHz',                 'Ω',      'IMPEDANCIA',   1),
  ('IMPEDANCIA_100KHZ',        'Impedância 100 kHz',                'Ω',      'IMPEDANCIA',   1),
  ('IMPEDANCIA_250KHZ',        'Impedância 250 kHz',                'Ω',      'IMPEDANCIA',   1),
  ('IMPEDANCIA_500KHZ',        'Impedância 500 kHz',                'Ω',      'IMPEDANCIA',   1),
  -- Antropometria manual (usar com regiao_id)
  ('PERIMETRO_CM',             'Perímetro',                         'cm',     'PERIMETRO',    1),
  ('DOBRA_CUTANEA_MM',         'Dobra cutânea',                     'mm',     'DOBRA_CUTANEA', 1),
  -- Exames laboratoriais
  ('GLICEMIA_JEJUM',           'Glicemia de jejum',                 'mg/dL',  'LABORATORIAL', 0),
  ('HBA1C',                    'Hemoglobina glicada (HbA1c)',       '%',      'LABORATORIAL', 1),
  ('INSULINA_JEJUM',           'Insulina de jejum',                 'µUI/mL', 'LABORATORIAL', 1),
  ('COLESTEROL_TOTAL',         'Colesterol total',                  'mg/dL',  'LABORATORIAL', 0),
  ('HDL',                      'HDL',                               'mg/dL',  'LABORATORIAL', 0),
  ('LDL',                      'LDL',                               'mg/dL',  'LABORATORIAL', 0),
  ('TRIGLICERIDEOS',           'Triglicerídeos',                    'mg/dL',  'LABORATORIAL', 0),
  ('VITAMINA_D',               'Vitamina D (25-OH)',                'ng/mL',  'LABORATORIAL', 1),
  ('VITAMINA_B12',             'Vitamina B12',                      'pg/mL',  'LABORATORIAL', 0),
  ('FERRITINA',                'Ferritina',                         'ng/mL',  'LABORATORIAL', 1),
  ('HEMOGLOBINA',              'Hemoglobina',                       'g/dL',   'LABORATORIAL', 1),
  ('TSH',                      'TSH',                               'µUI/mL', 'LABORATORIAL', 2),
  ('CREATININA',               'Creatinina',                        'mg/dL',  'LABORATORIAL', 2),
  ('ACIDO_URICO',              'Ácido úrico',                       'mg/dL',  'LABORATORIAL', 1),
  ('PCR_US',                   'Proteína C reativa ultrassensível', 'mg/L',   'LABORATORIAL', 2);

-- ---------------------------------------------------------------------
-- Regiões corporais
-- ---------------------------------------------------------------------
INSERT INTO regiao_corporal (codigo, nome, tipo) VALUES
  -- Segmentos da bioimpedância
  ('BRACO_DIR',        'Braço direito',        'SEGMENTO'),
  ('BRACO_ESQ',        'Braço esquerdo',       'SEGMENTO'),
  ('TRONCO',           'Tronco',               'SEGMENTO'),
  ('PERNA_DIR',        'Perna direita',        'SEGMENTO'),
  ('PERNA_ESQ',        'Perna esquerda',       'SEGMENTO'),
  -- Perímetros (fita métrica)
  ('PESCOCO',          'Pescoço',              'PERIMETRO'),
  ('TORAX',            'Tórax',                'PERIMETRO'),
  ('CINTURA',          'Cintura',              'PERIMETRO'),
  ('ABDOMEN',          'Abdômen',              'PERIMETRO'),
  ('QUADRIL',          'Quadril',              'PERIMETRO'),
  ('BRACO_DIR_RELAX',  'Braço direito relaxado',  'PERIMETRO'),
  ('BRACO_DIR_CONTR',  'Braço direito contraído', 'PERIMETRO'),
  ('COXA_DIR',         'Coxa direita',         'PERIMETRO'),
  ('PANTURRILHA_DIR',  'Panturrilha direita',  'PERIMETRO'),
  -- Dobras cutâneas (adipômetro)
  ('DC_TRICIPITAL',    'Tricipital',           'DOBRA'),
  ('DC_BICIPITAL',     'Bicipital',            'DOBRA'),
  ('DC_SUBESCAPULAR',  'Subescapular',         'DOBRA'),
  ('DC_PEITORAL',      'Peitoral',             'DOBRA'),
  ('DC_AXILAR_MEDIA',  'Axilar média',         'DOBRA'),
  ('DC_SUPRAILIACA',   'Suprailíaca',          'DOBRA'),
  ('DC_ABDOMINAL',     'Abdominal',            'DOBRA'),
  ('DC_COXA',          'Coxa',                 'DOBRA'),
  ('DC_PANTURRILHA',   'Panturrilha medial',   'DOBRA');

-- ---------------------------------------------------------------------
-- Condições
-- ---------------------------------------------------------------------
INSERT INTO tipo_condicao (nome) VALUES
  ('Alergia alimentar'),
  ('Intolerância alimentar'),
  ('Doença / condição clínica'),
  ('Restrição física'),
  ('Restrição ética / religiosa'),
  ('Aversão alimentar');

INSERT INTO condicao (tipo_condicao_id, nome)
SELECT t.id, c.nome
FROM (VALUES
  ('Alergia alimentar',           'Alergia à proteína do leite de vaca (APLV)'),
  ('Alergia alimentar',           'Alergia a amendoim'),
  ('Alergia alimentar',           'Alergia a frutos do mar'),
  ('Alergia alimentar',           'Alergia a ovo'),
  ('Intolerância alimentar',      'Intolerância à lactose'),
  ('Doença / condição clínica',   'Doença celíaca'),
  ('Doença / condição clínica',   'Diabetes mellitus tipo 2'),
  ('Doença / condição clínica',   'Hipertensão arterial'),
  ('Doença / condição clínica',   'Dislipidemia'),
  ('Doença / condição clínica',   'Hipotireoidismo'),
  ('Doença / condição clínica',   'Síndrome dos ovários policísticos'),
  ('Doença / condição clínica',   'Doença renal crônica'),
  ('Doença / condição clínica',   'Gestação'),
  ('Restrição física',            'Lesão / limitação articular'),
  ('Restrição física',            'Mobilidade reduzida'),
  ('Restrição ética / religiosa', 'Vegetarianismo'),
  ('Restrição ética / religiosa', 'Veganismo')
) AS c (tipo, nome)
JOIN tipo_condicao t ON t.nome = c.tipo;

-- ---------------------------------------------------------------------
-- Grupos alimentares (mesmos grupos da TACO, facilita a importação)
-- ---------------------------------------------------------------------
INSERT INTO grupo_alimentar (nome) VALUES
  ('Cereais e derivados'),
  ('Verduras, hortaliças e derivados'),
  ('Frutas e derivados'),
  ('Gorduras e óleos'),
  ('Pescados e frutos do mar'),
  ('Carnes e derivados'),
  ('Leite e derivados'),
  ('Bebidas'),
  ('Ovos e derivados'),
  ('Produtos açucarados'),
  ('Miscelâneas'),
  ('Outros alimentos industrializados'),
  ('Alimentos preparados'),
  ('Leguminosas e derivados'),
  ('Nozes e sementes');

-- ---------------------------------------------------------------------
-- Nutrientes (colunas de micronutrientes da TACO).
-- vd_referencia fica NULL: preencher conforme a IN ANVISA nº 75/2020.
-- ---------------------------------------------------------------------
INSERT INTO nutriente (nome, unidade) VALUES
  ('Colesterol',   'mg'),
  ('Cálcio',       'mg'),
  ('Magnésio',     'mg'),
  ('Manganês',     'mg'),
  ('Fósforo',      'mg'),
  ('Ferro',        'mg'),
  ('Sódio',        'mg'),
  ('Potássio',     'mg'),
  ('Cobre',        'mg'),
  ('Zinco',        'mg'),
  ('Retinol',      'µg'),
  ('Tiamina',      'mg'),
  ('Riboflavina',  'mg'),
  ('Piridoxina',   'mg'),
  ('Niacina',      'mg'),
  ('Vitamina C',   'mg');

-- ---------------------------------------------------------------------
-- Equipamentos (exemplo — o nutricionista pode cadastrar os seus)
-- ---------------------------------------------------------------------
INSERT INTO equipamento (tipo, marca, modelo) VALUES
  ('BIOIMPEDANCIA', 'Relaxmedic', 'Balança de bioimpedância (modelo a confirmar)');
