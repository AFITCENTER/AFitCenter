-- =====================================================================
-- AFitCenter — schema do banco (PostgreSQL 15+)
--
-- Decisões de modelagem (v1):
--   * Multi-nutricionista: o nutricionista é o "tenant". Cada nutricionista
--     tem a sua própria ficha de paciente; a mesma pessoa pode ter fichas em
--     vários nutricionistas, isoladas entre si (CPF único POR nutricionista).
--   * Tabelas raiz (paciente, consultorio, consulta, avaliacao, dieta, exame)
--     carregam nutricionista_id. Tabelas de detalhe herdam o dono pelo pai.
--     FKs compostas garantem que consulta/avaliação/dieta/exame apontem
--     para um paciente do MESMO nutricionista.
--   * Pessoa é quem acessa: nome, CPF, e-mail (login), senha e um ou mais papéis.
--     O nutricionista é o perfil profissional da pessoa (mesmo id). O paciente
--     cria a própria conta e liga as fichas com o código de acesso que o
--     nutricionista gera: um login enxerga todas as fichas dele, uma por
--     nutricionista (paciente.pessoa_id).
--   * Estudante fica fora da v1.
--   * Dados clínicos usam exclusão lógica (deletado_em): prontuário não se apaga.
--   * IDs: uuid para dados de negócio, integer identity para catálogos.
--   * Domínios fechados: text + CHECK (mais fácil de evoluir que ENUM).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Utilitários
-- ---------------------------------------------------------------------
CREATE FUNCTION set_atualizado_em() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.atualizado_em := now();
  RETURN NEW;
END $$;

-- ---------------------------------------------------------------------
-- 1. Acesso
-- ---------------------------------------------------------------------
CREATE TABLE pessoa (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome           text NOT NULL,
  cpf            char(11),                            -- opcional para paciente; o nutricionista informa no cadastro
  email          text NOT NULL,                       -- login
  email_confirmado_em timestamptz,                    -- quando abriu um link enviado ao e-mail; o login não exige
  telefone       text,
  senha_hash     text NOT NULL,                       -- bcrypt/argon2, nunca a senha
  status         text NOT NULL DEFAULT 'ATIVO' CHECK (status IN ('ATIVO', 'BLOQUEADO', 'INATIVO')),
  ultimo_acesso  timestamptz,
  criado_em      timestamptz NOT NULL DEFAULT now(),
  atualizado_em  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_pessoa_email ON pessoa (lower(email));
CREATE UNIQUE INDEX ux_pessoa_cpf ON pessoa (cpf) WHERE cpf IS NOT NULL;   -- uma conta por pessoa

-- Uma pessoa pode ter vários papéis (a nutricionista que também é paciente de um colega)
CREATE TABLE pessoa_papel (
  pessoa_id  uuid NOT NULL REFERENCES pessoa (id) ON DELETE CASCADE,
  papel      text NOT NULL CHECK (papel IN ('NUTRICIONISTA', 'PACIENTE', 'ADMIN')),
  PRIMARY KEY (pessoa_id, papel)
);

-- LGPD: registro de aceite de termos e política de privacidade
CREATE TABLE aceite_termo (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id   uuid NOT NULL REFERENCES pessoa (id),
  tipo        text NOT NULL CHECK (tipo IN ('TERMOS_DE_USO', 'POLITICA_PRIVACIDADE')),
  versao      text NOT NULL,
  aceito_em   timestamptz NOT NULL DEFAULT now(),
  ip          inet,
  UNIQUE (pessoa_id, tipo, versao)
);

-- Links enviados por e-mail: redefinição de senha (30 min) e confirmação do e-mail (48 h).
-- Uso único; pedir outro substitui o anterior. Só o hash é guardado.
CREATE TABLE token_email (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id   uuid NOT NULL REFERENCES pessoa (id) ON DELETE CASCADE,
  finalidade  text NOT NULL CHECK (finalidade IN ('REDEFINICAO_SENHA', 'CONFIRMACAO_EMAIL')),
  token_hash  text NOT NULL UNIQUE,                    -- SHA-256 do token, nunca o token
  expira_em   timestamptz NOT NULL,
  criado_em   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_token_email_pessoa ON token_email (pessoa_id, finalidade);

-- ---------------------------------------------------------------------
-- 2. Cadastro do nutricionista (requisito 7)
-- ---------------------------------------------------------------------
CREATE TABLE endereco (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cep            char(8),
  logradouro     text NOT NULL,
  numero         text,
  complemento    text,
  bairro         text,
  cidade         text NOT NULL,
  uf             char(2) NOT NULL,
  criado_em      timestamptz NOT NULL DEFAULT now(),
  atualizado_em  timestamptz NOT NULL DEFAULT now()
);

-- Perfil profissional. Nome, CPF, e-mail e telefone ficam na pessoa (mesmo id).
CREATE TABLE nutricionista (
  id               uuid PRIMARY KEY REFERENCES pessoa (id),
  crn_regiao       smallint NOT NULL CHECK (crn_regiao > 0),  -- CRN-3 → 3
  crn_numero       text NOT NULL,
  especialidades   text,
  assinatura_url   text,                                      -- usada no PDF da dieta
  logo_url         text,
  endereco_id      uuid REFERENCES endereco (id),          -- endereço profissional
  criado_em        timestamptz NOT NULL DEFAULT now(),
  atualizado_em    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (crn_regiao, crn_numero)
);

CREATE TABLE consultorio (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nutricionista_id  uuid NOT NULL REFERENCES nutricionista (id),
  nome              text NOT NULL,
  endereco_id       uuid REFERENCES endereco (id),
  ativo             boolean NOT NULL DEFAULT true,
  criado_em         timestamptz NOT NULL DEFAULT now(),
  atualizado_em     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, nutricionista_id)                               -- alvo de FK composta
);

-- ---------------------------------------------------------------------
-- 3. Paciente (requisito 1)
-- ---------------------------------------------------------------------
CREATE TABLE paciente (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nutricionista_id  uuid NOT NULL REFERENCES nutricionista (id),
  pessoa_id         uuid REFERENCES pessoa (id),              -- conta do paciente no portal; NULL = sem acesso
  pessoa_vinculada_em timestamptz,
  nome              text NOT NULL,
  nome_social       text,
  cpf               char(11),                                 -- opcional (ex.: crianças)
  data_nascimento   date NOT NULL,                            -- idade é sempre calculada
  sexo              char(1) NOT NULL CHECK (sexo IN ('F', 'M')),  -- sexo biológico: usado nas equações
  ocupacao          text,
  objetivo          text,
  nivel_atividade   text CHECK (nivel_atividade IN ('SEDENTARIO', 'LEVE', 'MODERADO', 'INTENSO', 'MUITO_INTENSO')),
  observacoes       text,
  status            text NOT NULL DEFAULT 'ATIVO' CHECK (status IN ('ATIVO', 'INATIVO')),
  endereco_id       uuid REFERENCES endereco (id),
  criado_em         timestamptz NOT NULL DEFAULT now(),
  atualizado_em     timestamptz NOT NULL DEFAULT now(),
  deletado_em       timestamptz,
  UNIQUE (id, nutricionista_id)                               -- alvo de FK composta
);
-- Mesma pessoa pode ser paciente de vários nutricionistas, mas não duplicada no mesmo
CREATE UNIQUE INDEX ux_paciente_cpf_por_nutricionista
  ON paciente (nutricionista_id, cpf) WHERE cpf IS NOT NULL AND deletado_em IS NULL;
CREATE INDEX ix_paciente_nutricionista_nome ON paciente (nutricionista_id, nome);
-- Uma conta tem no máximo uma ficha ativa por nutricionista
CREATE UNIQUE INDEX ux_paciente_pessoa_por_nutricionista
  ON paciente (nutricionista_id, pessoa_id) WHERE pessoa_id IS NOT NULL AND deletado_em IS NULL;
CREATE INDEX ix_paciente_pessoa ON paciente (pessoa_id) WHERE pessoa_id IS NOT NULL AND deletado_em IS NULL;

-- Código que o nutricionista entrega ao paciente para ligar a ficha à conta dele.
-- Um por ficha, de uso único e com validade; só o hash é guardado.
CREATE TABLE codigo_acesso (
  paciente_id  uuid PRIMARY KEY REFERENCES paciente (id) ON DELETE CASCADE,
  codigo_hash  text NOT NULL UNIQUE,                          -- SHA-256 do código
  expira_em    timestamptz NOT NULL,
  criado_em    timestamptz NOT NULL DEFAULT now()
);

-- Contato pertence a exatamente um dono (nutricionista, paciente ou consultório)
CREATE TABLE contato (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nutricionista_id  uuid REFERENCES nutricionista (id) ON DELETE CASCADE,
  paciente_id       uuid REFERENCES paciente (id) ON DELETE CASCADE,
  consultorio_id    uuid REFERENCES consultorio (id) ON DELETE CASCADE,
  tipo              text NOT NULL CHECK (tipo IN ('CELULAR', 'WHATSAPP', 'TELEFONE', 'EMAIL', 'INSTAGRAM', 'OUTRO')),
  valor             text NOT NULL,
  principal         boolean NOT NULL DEFAULT false,
  observacao        text,                                     -- ex.: "telefone da mãe"
  CHECK (num_nonnulls(nutricionista_id, paciente_id, consultorio_id) = 1)
);
CREATE INDEX ix_contato_paciente ON contato (paciente_id) WHERE paciente_id IS NOT NULL;

-- Catálogo de condições: alergias, intolerâncias, doenças, restrições físicas...
CREATE TABLE tipo_condicao (
  id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome  text NOT NULL UNIQUE
);

CREATE TABLE condicao (
  id                integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tipo_condicao_id  integer NOT NULL REFERENCES tipo_condicao (id),
  nutricionista_id  uuid REFERENCES nutricionista (id),       -- NULL = catálogo do sistema
  nome              text NOT NULL,
  descricao         text,
  UNIQUE NULLS NOT DISTINCT (nutricionista_id, nome)
);

CREATE TABLE paciente_condicao (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  paciente_id  uuid NOT NULL REFERENCES paciente (id) ON DELETE CASCADE,
  condicao_id  integer NOT NULL REFERENCES condicao (id),
  gravidade    text CHECK (gravidade IN ('LEVE', 'MODERADA', 'GRAVE')),
  desde        date,
  ativa        boolean NOT NULL DEFAULT true,
  observacao   text,
  criado_em    timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  UNIQUE (paciente_id, condicao_id)
);

CREATE TABLE paciente_medicamento (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  paciente_id  uuid NOT NULL REFERENCES paciente (id) ON DELETE CASCADE,
  tipo         text NOT NULL CHECK (tipo IN ('MEDICAMENTO', 'SUPLEMENTO', 'FITOTERAPICO')),
  nome         text NOT NULL,
  dosagem      text,
  frequencia   text,
  inicio       date,
  fim          date,
  observacao   text,
  criado_em    timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  CHECK (fim IS NULL OR inicio IS NULL OR fim >= inicio)
);
CREATE INDEX ix_paciente_medicamento_paciente ON paciente_medicamento (paciente_id);

-- ---------------------------------------------------------------------
-- 4. Consulta (requisito 4) e análises do nutricionista (requisito 2)
-- ---------------------------------------------------------------------
CREATE TABLE consulta (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nutricionista_id  uuid NOT NULL,
  paciente_id       uuid NOT NULL,
  consultorio_id    uuid,                                     -- NULL = online
  data_hora         timestamptz NOT NULL,
  duracao_min       smallint CHECK (duracao_min > 0),
  tipo              text NOT NULL CHECK (tipo IN ('PRIMEIRA', 'RETORNO')),
  modalidade        text NOT NULL CHECK (modalidade IN ('PRESENCIAL', 'ONLINE')),
  status            text NOT NULL DEFAULT 'AGENDADA'
                    CHECK (status IN ('AGENDADA', 'CONFIRMADA', 'REALIZADA', 'CANCELADA', 'FALTOU')),
  valor             numeric(10,2) CHECK (valor >= 0),
  observacao        text,
  criado_em         timestamptz NOT NULL DEFAULT now(),
  atualizado_em     timestamptz NOT NULL DEFAULT now(),
  deletado_em       timestamptz,
  FOREIGN KEY (paciente_id, nutricionista_id)    REFERENCES paciente (id, nutricionista_id),
  FOREIGN KEY (consultorio_id, nutricionista_id) REFERENCES consultorio (id, nutricionista_id),
  UNIQUE (id, paciente_id)                                    -- alvo de FK composta
);
CREATE INDEX ix_consulta_agenda   ON consulta (nutricionista_id, data_hora);
CREATE INDEX ix_consulta_paciente ON consulta (paciente_id, data_hora);

CREATE TABLE analise (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consulta_id    uuid NOT NULL REFERENCES consulta (id),
  categoria      text NOT NULL CHECK (categoria IN
                   ('ANAMNESE', 'QUEIXA', 'ACHADO', 'DIAGNOSTICO_NUTRICIONAL', 'CONDUTA', 'OUTRO')),
  descricao      text NOT NULL,
  criado_em      timestamptz NOT NULL DEFAULT now(),
  atualizado_em  timestamptz NOT NULL DEFAULT now(),
  deletado_em    timestamptz
);
CREATE INDEX ix_analise_consulta ON analise (consulta_id);

-- ---------------------------------------------------------------------
-- 5. Avaliação corporal (requisito 3): catálogo de métricas
-- ---------------------------------------------------------------------
CREATE TABLE metrica (
  id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo          text NOT NULL UNIQUE,                       -- GORDURA_PCT, AGUA_KG, IMPEDANCIA_20KHZ...
  nome            text NOT NULL,
  unidade         text NOT NULL,
  categoria       text NOT NULL CHECK (categoria IN
                    ('BASICA', 'COMPOSICAO', 'INDICE', 'SEGMENTAR', 'IMPEDANCIA',
                     'PERIMETRO', 'DOBRA_CUTANEA', 'LABORATORIAL')),
  casas_decimais  smallint NOT NULL DEFAULT 1
);

CREATE TABLE regiao_corporal (
  id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo  text NOT NULL UNIQUE,
  nome    text NOT NULL,
  tipo    text NOT NULL CHECK (tipo IN ('SEGMENTO', 'PERIMETRO', 'DOBRA'))
);

CREATE TABLE equipamento (
  id                integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nutricionista_id  uuid REFERENCES nutricionista (id),       -- NULL = catálogo do sistema
  tipo              text NOT NULL CHECK (tipo IN ('BIOIMPEDANCIA', 'BALANCA', 'ADIPOMETRO', 'FITA', 'OUTRO')),
  marca             text NOT NULL,
  modelo            text NOT NULL,
  UNIQUE NULLS NOT DISTINCT (nutricionista_id, marca, modelo)
);

CREATE TABLE avaliacao (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nutricionista_id   uuid NOT NULL,
  paciente_id        uuid NOT NULL,
  consulta_id        uuid,                                    -- opcional: laudo pode chegar fora da consulta
  equipamento_id     integer REFERENCES equipamento (id),
  metodo             text NOT NULL CHECK (metodo IN ('BIOIMPEDANCIA', 'ANTROPOMETRIA', 'MISTA')),
  data_hora_medicao  timestamptz NOT NULL,
  peso_kg            numeric(5,2) NOT NULL CHECK (peso_kg > 0),
  altura_cm          numeric(5,1) NOT NULL CHECK (altura_cm > 0),
  imc                numeric(5,2) GENERATED ALWAYS AS (round(peso_kg / ((altura_cm / 100) ^ 2), 2)) STORED,
  em_jejum           boolean,
  observacao         text,
  laudo_url          text,                                    -- PDF/foto do laudo original
  criado_em          timestamptz NOT NULL DEFAULT now(),
  atualizado_em      timestamptz NOT NULL DEFAULT now(),
  deletado_em        timestamptz,
  FOREIGN KEY (paciente_id, nutricionista_id) REFERENCES paciente (id, nutricionista_id),
  FOREIGN KEY (consulta_id, paciente_id)      REFERENCES consulta (id, paciente_id)
);
CREATE INDEX ix_avaliacao_paciente ON avaliacao (paciente_id, data_hora_medicao);

-- Uma linha por valor do laudo. regiao_id NULL = valor do corpo inteiro.
CREATE TABLE avaliacao_resultado (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  avaliacao_id   uuid NOT NULL REFERENCES avaliacao (id) ON DELETE CASCADE,
  metrica_id     integer NOT NULL REFERENCES metrica (id),
  regiao_id      integer REFERENCES regiao_corporal (id),
  valor          numeric(10,3) NOT NULL,
  ref_min        numeric(10,3),                               -- faixa de referência impressa no laudo
  ref_max        numeric(10,3),
  classificacao  text,                                        -- rótulo do aparelho: "Alto", "Saudável"...
  UNIQUE NULLS NOT DISTINCT (avaliacao_id, metrica_id, regiao_id)
);
CREATE INDEX ix_avaliacao_resultado_metrica ON avaliacao_resultado (metrica_id);

CREATE TABLE meta (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  paciente_id   uuid NOT NULL REFERENCES paciente (id) ON DELETE CASCADE,
  metrica_id    integer NOT NULL REFERENCES metrica (id),
  valor_alvo    numeric(10,3) NOT NULL,
  data_inicio   date NOT NULL DEFAULT current_date,
  prazo         date,
  status        text NOT NULL DEFAULT 'ATIVA' CHECK (status IN ('ATIVA', 'ATINGIDA', 'CANCELADA')),
  observacao    text,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  CHECK (prazo IS NULL OR prazo >= data_inicio)
);
CREATE INDEX ix_meta_paciente ON meta (paciente_id);

-- ---------------------------------------------------------------------
-- 6. Alimentos
-- ---------------------------------------------------------------------
CREATE TABLE grupo_alimentar (
  id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome  text NOT NULL UNIQUE
);

CREATE TABLE alimento (
  id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nutricionista_id    uuid REFERENCES nutricionista (id),     -- NULL = base oficial (TACO/TBCA)
  grupo_alimentar_id  integer REFERENCES grupo_alimentar (id),
  nome                text NOT NULL,
  fonte               text NOT NULL CHECK (fonte IN ('TACO', 'TBCA', 'PROPRIO')),
  codigo_fonte        text,                                   -- código na tabela de origem
  porcao_base_g       numeric(7,2) NOT NULL DEFAULT 100 CHECK (porcao_base_g > 0),
  -- macros na porção base: lidos o tempo todo para somar a dieta
  kcal                numeric(7,2),
  proteina_g          numeric(7,2),
  carboidrato_g       numeric(7,2),
  lipidio_g           numeric(7,2),
  fibra_g             numeric(7,2),
  ativo               boolean NOT NULL DEFAULT true,
  criado_em           timestamptz NOT NULL DEFAULT now(),
  atualizado_em       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_alimento_nome ON alimento (lower(nome));

-- Medidas caseiras: "1 colher de sopa cheia" = 25 g
CREATE TABLE alimento_medida (
  id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  alimento_id  integer NOT NULL REFERENCES alimento (id) ON DELETE CASCADE,
  descricao    text NOT NULL,
  gramas       numeric(7,2) NOT NULL CHECK (gramas > 0),
  UNIQUE (alimento_id, descricao),
  UNIQUE (id, alimento_id)                                    -- alvo de FK composta
);

-- Micronutrientes (macros ficam em colunas do alimento). %VD é calculado, não armazenado.
CREATE TABLE nutriente (
  id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome           text NOT NULL UNIQUE,
  unidade        text NOT NULL,
  vd_referencia  numeric(10,3)
);

CREATE TABLE alimento_nutriente (
  alimento_id   integer NOT NULL REFERENCES alimento (id) ON DELETE CASCADE,
  nutriente_id  integer NOT NULL REFERENCES nutriente (id),
  quantidade    numeric(10,3) NOT NULL CHECK (quantidade >= 0),  -- na porção base
  PRIMARY KEY (alimento_id, nutriente_id)
);

-- Liga condição a alimentos/grupos que ela restringe → alerta ao montar a dieta
CREATE TABLE condicao_restricao (
  id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  condicao_id         integer NOT NULL REFERENCES condicao (id) ON DELETE CASCADE,
  alimento_id         integer REFERENCES alimento (id),
  grupo_alimentar_id  integer REFERENCES grupo_alimentar (id),
  CHECK (num_nonnulls(alimento_id, grupo_alimentar_id) = 1),
  UNIQUE NULLS NOT DISTINCT (condicao_id, alimento_id, grupo_alimentar_id)
);

-- ---------------------------------------------------------------------
-- 7. Dieta (requisito 5)
-- ---------------------------------------------------------------------
CREATE TABLE dieta (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nutricionista_id    uuid NOT NULL REFERENCES nutricionista (id),
  paciente_id         uuid,                                   -- NULL quando é modelo
  consulta_id         uuid,
  dieta_origem_id     uuid REFERENCES dieta (id),             -- modelo de origem ou versão anterior
  is_modelo           boolean NOT NULL DEFAULT false,
  titulo              text NOT NULL,
  objetivo            text,
  kcal_meta           numeric(7,1),
  proteina_meta_g     numeric(6,1),
  carboidrato_meta_g  numeric(6,1),
  lipidio_meta_g      numeric(6,1),
  data_inicio         date,
  data_fim            date,
  status              text NOT NULL DEFAULT 'RASCUNHO' CHECK (status IN ('RASCUNHO', 'ATIVA', 'ENCERRADA')),
  observacao          text,
  criado_em           timestamptz NOT NULL DEFAULT now(),
  atualizado_em       timestamptz NOT NULL DEFAULT now(),
  deletado_em         timestamptz,
  FOREIGN KEY (paciente_id, nutricionista_id) REFERENCES paciente (id, nutricionista_id),
  FOREIGN KEY (consulta_id, paciente_id)      REFERENCES consulta (id, paciente_id),
  CHECK (is_modelo = (paciente_id IS NULL)),
  CHECK (data_fim IS NULL OR data_inicio IS NULL OR data_fim >= data_inicio)
);
CREATE INDEX ix_dieta_paciente ON dieta (paciente_id) WHERE paciente_id IS NOT NULL;
CREATE INDEX ix_dieta_modelos  ON dieta (nutricionista_id) WHERE is_modelo;

CREATE TABLE refeicao (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dieta_id     uuid NOT NULL REFERENCES dieta (id) ON DELETE CASCADE,
  nome         text NOT NULL,                                 -- "Café da manhã"
  horario      time,
  ordem        smallint NOT NULL,
  dias_semana  smallint[] NOT NULL DEFAULT '{1,2,3,4,5,6,7}'  -- ISO: 1 = segunda ... 7 = domingo
               CHECK (cardinality(dias_semana) > 0 AND dias_semana <@ '{1,2,3,4,5,6,7}'),
  observacao   text
);
CREATE INDEX ix_refeicao_dieta ON refeicao (dieta_id, ordem);

CREATE TABLE refeicao_item (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  refeicao_id         uuid NOT NULL REFERENCES refeicao (id) ON DELETE CASCADE,
  alimento_id         integer NOT NULL REFERENCES alimento (id),
  opcao               smallint NOT NULL DEFAULT 1 CHECK (opcao >= 1),  -- "Opção 1", "Opção 2"
  quantidade          numeric(7,2) NOT NULL CHECK (quantidade > 0),    -- na medida escolhida
  alimento_medida_id  integer,                                         -- NULL = gramas
  quantidade_g        numeric(8,2) NOT NULL CHECK (quantidade_g > 0),  -- base dos cálculos (snapshot)
  ordem               smallint NOT NULL DEFAULT 1,
  observacao          text,
  FOREIGN KEY (alimento_medida_id, alimento_id) REFERENCES alimento_medida (id, alimento_id)
);
CREATE INDEX ix_refeicao_item_refeicao ON refeicao_item (refeicao_id);

CREATE TABLE refeicao_item_substituto (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  refeicao_item_id    uuid NOT NULL REFERENCES refeicao_item (id) ON DELETE CASCADE,
  alimento_id         integer NOT NULL REFERENCES alimento (id),
  quantidade          numeric(7,2) NOT NULL CHECK (quantidade > 0),
  alimento_medida_id  integer,
  quantidade_g        numeric(8,2) NOT NULL CHECK (quantidade_g > 0),
  FOREIGN KEY (alimento_medida_id, alimento_id) REFERENCES alimento_medida (id, alimento_id)
);
CREATE INDEX ix_substituto_item ON refeicao_item_substituto (refeicao_item_id);

-- ---------------------------------------------------------------------
-- 8. Exames (requisito 6)
-- ---------------------------------------------------------------------
CREATE TABLE exame (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nutricionista_id  uuid NOT NULL,
  paciente_id       uuid NOT NULL,
  consulta_id       uuid,                                     -- exames chegam entre consultas
  nome              text NOT NULL,                            -- "Perfil lipídico", "Hemograma"
  laboratorio       text,
  data_coleta       date NOT NULL,
  observacao        text,
  criado_em         timestamptz NOT NULL DEFAULT now(),
  atualizado_em     timestamptz NOT NULL DEFAULT now(),
  deletado_em       timestamptz,
  FOREIGN KEY (paciente_id, nutricionista_id) REFERENCES paciente (id, nutricionista_id),
  FOREIGN KEY (consulta_id, paciente_id)      REFERENCES consulta (id, paciente_id)
);
CREATE INDEX ix_exame_paciente ON exame (paciente_id, data_coleta);

-- Arquivo fica no storage (S3, R2...); no banco só a chave
CREATE TABLE exame_anexo (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exame_id       uuid NOT NULL REFERENCES exame (id) ON DELETE CASCADE,
  storage_key    text NOT NULL,
  nome_arquivo   text NOT NULL,
  mime_type      text NOT NULL,
  tamanho_bytes  bigint CHECK (tamanho_bytes >= 0),
  criado_em      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_exame_anexo_exame ON exame_anexo (exame_id);

-- Resultados estruturados reaproveitam o catálogo de métricas → mesmo gráfico de evolução
CREATE TABLE exame_resultado (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exame_id    uuid NOT NULL REFERENCES exame (id) ON DELETE CASCADE,
  metrica_id  integer NOT NULL REFERENCES metrica (id),
  valor       numeric(12,3) NOT NULL,
  ref_min     numeric(12,3),
  ref_max     numeric(12,3),
  observacao  text,
  UNIQUE (exame_id, metrica_id)
);
CREATE INDEX ix_exame_resultado_metrica ON exame_resultado (metrica_id);

-- ---------------------------------------------------------------------
-- 9. Evolução (requisito 3): uma série temporal única para gráficos e comparação
--    Junta resultados da avaliação, peso/altura/IMC (colunas) e exames.
-- ---------------------------------------------------------------------
CREATE VIEW vw_evolucao AS
SELECT a.nutricionista_id, a.paciente_id, 'AVALIACAO' AS origem, a.id AS origem_id,
       a.data_hora_medicao AS data_hora, a.equipamento_id,
       m.codigo AS metrica, m.nome AS metrica_nome, m.unidade,
       rc.codigo AS regiao, r.valor, r.ref_min, r.ref_max
FROM avaliacao a
JOIN avaliacao_resultado r  ON r.avaliacao_id = a.id
JOIN metrica m              ON m.id = r.metrica_id
LEFT JOIN regiao_corporal rc ON rc.id = r.regiao_id
WHERE a.deletado_em IS NULL
UNION ALL
SELECT a.nutricionista_id, a.paciente_id, 'AVALIACAO', a.id,
       a.data_hora_medicao, a.equipamento_id,
       m.codigo, m.nome, m.unidade,
       NULL, v.valor, NULL, NULL
FROM avaliacao a
CROSS JOIN LATERAL (VALUES ('PESO', a.peso_kg), ('ALTURA', a.altura_cm), ('IMC', a.imc)) AS v (codigo, valor)
JOIN metrica m ON m.codigo = v.codigo
WHERE a.deletado_em IS NULL
UNION ALL
SELECT e.nutricionista_id, e.paciente_id, 'EXAME', e.id,
       e.data_coleta::timestamptz, NULL,
       m.codigo, m.nome, m.unidade,
       NULL, er.valor, er.ref_min, er.ref_max
FROM exame e
JOIN exame_resultado er ON er.exame_id = e.id
JOIN metrica m          ON m.id = er.metrica_id
WHERE e.deletado_em IS NULL;

-- ---------------------------------------------------------------------
-- 10. Trigger de atualizado_em em todas as tabelas que têm a coluna
-- ---------------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOR t IN
    SELECT c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables tb
      ON tb.table_schema = c.table_schema AND tb.table_name = c.table_name
    WHERE c.table_schema = current_schema()
      AND c.column_name = 'atualizado_em'
      AND tb.table_type = 'BASE TABLE'
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_atualizado_em BEFORE UPDATE ON %1$I
         FOR EACH ROW EXECUTE FUNCTION set_atualizado_em()', t);
  END LOOP;
END $$;
