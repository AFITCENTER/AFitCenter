# AFitCenter — MER revisado (v1)

## Decisões

| Decisão | Consequência no modelo |
|---|---|
| Vários nutricionistas, cada um com seus pacientes | O nutricionista é o *tenant*. Cada um tem a **própria ficha** do paciente; a mesma pessoa pode ter fichas em vários nutricionistas, isoladas entre si. CPF é único **por nutricionista**. |
| Estudante fora da v1 | Entidade removida (volta depois como papel ligado a um nutricionista supervisor). |
| Paciente sem acesso na v1, com acesso no futuro | `paciente.usuario_id` já existe (opcional). No futuro, um único login de paciente enxerga todas as fichas dele, uma por nutricionista. |

## Convenções

- **Tabelas raiz** (paciente, consultorio, consulta, avaliacao, dieta, exame) têm `nutricionista_id`. Tabelas de detalhe herdam o dono pelo pai.
- **FKs compostas** garantem que a consulta, avaliação, dieta e exame apontem para um paciente do **mesmo** nutricionista, e que avaliação/dieta/exame de um paciente não fiquem ligados à consulta de outro.
- **Catálogos** com `nutricionista_id` nulo são do sistema; preenchido = cadastro próprio do nutricionista (condicao, alimento, equipamento).
- **Auditoria** (`criado_em`, `atualizado_em`) em todas as tabelas de cadastro; **exclusão lógica** (`deletado_em`) em paciente, consulta, analise, avaliacao, dieta e exame. Essas colunas foram omitidas dos diagramas.
- **Idade e IMC são derivados**: idade de `data_nascimento`; IMC é coluna gerada, `peso_kg / (altura_cm/100)²`.

---

## Visão geral

```mermaid
erDiagram
    USUARIO ||--o| NUTRICIONISTA : "acessa como"
    USUARIO |o--o{ PACIENTE : "acessa (futuro)"
    USUARIO ||--o{ ACEITE_TERMO : aceita
    NUTRICIONISTA ||--o{ CONSULTORIO : possui
    NUTRICIONISTA ||--o{ PACIENTE : atende
    NUTRICIONISTA ||--o{ CONSULTA : realiza
    NUTRICIONISTA ||--o{ DIETA : prescreve
    PACIENTE ||--o{ CONSULTA : agenda
    CONSULTORIO |o--o{ CONSULTA : sedia
    PACIENTE ||--o{ PACIENTE_CONDICAO : tem
    CONDICAO ||--o{ PACIENTE_CONDICAO : ""
    TIPO_CONDICAO ||--o{ CONDICAO : classifica
    PACIENTE ||--o{ PACIENTE_MEDICAMENTO : usa
    PACIENTE ||--o{ META : persegue
    CONSULTA ||--o{ ANALISE : registra
    PACIENTE ||--o{ AVALIACAO : realiza
    CONSULTA |o--o{ AVALIACAO : gera
    AVALIACAO ||--o{ AVALIACAO_RESULTADO : contem
    METRICA ||--o{ AVALIACAO_RESULTADO : mede
    PACIENTE |o--o{ DIETA : segue
    CONSULTA |o--o{ DIETA : gera
    DIETA ||--o{ REFEICAO : contem
    REFEICAO ||--o{ REFEICAO_ITEM : contem
    ALIMENTO ||--o{ REFEICAO_ITEM : compoe
    CONDICAO ||--o{ CONDICAO_RESTRICAO : restringe
    ALIMENTO |o--o{ CONDICAO_RESTRICAO : ""
    PACIENTE ||--o{ EXAME : apresenta
    CONSULTA |o--o{ EXAME : ""
    EXAME ||--o{ EXAME_RESULTADO : contem
    METRICA ||--o{ EXAME_RESULTADO : mede
```

---

## 1. Acesso e cadastro (requisitos 1 e 7)

```mermaid
erDiagram
    USUARIO ||--o| NUTRICIONISTA : "acessa como"
    USUARIO |o--o{ PACIENTE : "acessa (futuro)"
    USUARIO ||--o{ ACEITE_TERMO : aceita
    NUTRICIONISTA ||--o{ CONSULTORIO : possui
    NUTRICIONISTA ||--o{ PACIENTE : atende
    NUTRICIONISTA |o--o| ENDERECO : "mora em"
    CONSULTORIO |o--o| ENDERECO : "fica em"
    PACIENTE |o--o| ENDERECO : "mora em"
    NUTRICIONISTA ||--o{ CONTATO : tem
    PACIENTE ||--o{ CONTATO : tem
    CONSULTORIO ||--o{ CONTATO : tem

    USUARIO {
        uuid id PK
        text email UK "login, case-insensitive"
        text senha_hash "bcrypt ou argon2"
        text perfil "NUTRICIONISTA, PACIENTE, ADMIN"
        text status "ATIVO, BLOQUEADO, INATIVO"
        timestamptz ultimo_acesso
    }
    ACEITE_TERMO {
        uuid id PK
        uuid usuario_id FK
        text tipo "TERMOS_DE_USO, POLITICA_PRIVACIDADE"
        text versao
        timestamptz aceito_em
        inet ip
    }
    NUTRICIONISTA {
        uuid id PK
        uuid usuario_id FK, UK
        text nome
        char cpf UK
        smallint crn_regiao "CRN-3 = 3"
        text crn_numero "único por região"
        text especialidades
        text assinatura_url "PDF da dieta"
        text logo_url
        uuid endereco_id FK
    }
    CONSULTORIO {
        uuid id PK
        uuid nutricionista_id FK
        text nome
        uuid endereco_id FK
        bool ativo
    }
    PACIENTE {
        uuid id PK
        uuid nutricionista_id FK "dono da ficha"
        uuid usuario_id FK "nulo na v1"
        text nome
        text nome_social
        char cpf "único por nutricionista"
        date data_nascimento "idade é derivada"
        char sexo "biológico: F, M"
        text ocupacao
        text objetivo
        text nivel_atividade "SEDENTARIO a MUITO_INTENSO"
        text status "ATIVO, INATIVO"
        uuid endereco_id FK
    }
    ENDERECO {
        uuid id PK
        char cep
        text logradouro
        text numero
        text complemento
        text bairro
        text cidade
        char uf
    }
    CONTATO {
        uuid id PK
        uuid nutricionista_id FK "exatamente um dono"
        uuid paciente_id FK
        uuid consultorio_id FK
        text tipo "CELULAR, WHATSAPP, EMAIL..."
        text valor
        bool principal
    }
```

## 2. Prontuário: condições, consultas e análises (requisitos 1, 2 e 4)

```mermaid
erDiagram
    PACIENTE ||--o{ PACIENTE_CONDICAO : tem
    CONDICAO ||--o{ PACIENTE_CONDICAO : ""
    TIPO_CONDICAO ||--o{ CONDICAO : classifica
    NUTRICIONISTA |o--o{ CONDICAO : "cadastra própria"
    PACIENTE ||--o{ PACIENTE_MEDICAMENTO : usa
    PACIENTE ||--o{ CONSULTA : agenda
    NUTRICIONISTA ||--o{ CONSULTA : realiza
    CONSULTORIO |o--o{ CONSULTA : sedia
    CONSULTA ||--o{ ANALISE : registra
    PACIENTE ||--o{ META : persegue
    METRICA ||--o{ META : mede

    TIPO_CONDICAO {
        int id PK
        text nome UK "alergia, intolerância, doença, restrição física..."
    }
    CONDICAO {
        int id PK
        int tipo_condicao_id FK
        uuid nutricionista_id FK "nulo = catálogo do sistema"
        text nome
        text descricao
    }
    PACIENTE_CONDICAO {
        uuid id PK
        uuid paciente_id FK
        int condicao_id FK
        text gravidade "LEVE, MODERADA, GRAVE"
        date desde
        bool ativa
        text observacao
    }
    PACIENTE_MEDICAMENTO {
        uuid id PK
        uuid paciente_id FK
        text tipo "MEDICAMENTO, SUPLEMENTO, FITOTERAPICO"
        text nome
        text dosagem
        text frequencia
        date inicio
        date fim
    }
    CONSULTA {
        uuid id PK
        uuid nutricionista_id FK
        uuid paciente_id FK "mesmo nutricionista"
        uuid consultorio_id FK "nulo = online"
        timestamptz data_hora
        smallint duracao_min
        text tipo "PRIMEIRA, RETORNO"
        text modalidade "PRESENCIAL, ONLINE"
        text status "AGENDADA, CONFIRMADA, REALIZADA, CANCELADA, FALTOU"
        numeric valor
        text observacao
    }
    ANALISE {
        uuid id PK
        uuid consulta_id FK
        text categoria "ANAMNESE, QUEIXA, ACHADO, DIAGNOSTICO_NUTRICIONAL, CONDUTA"
        text descricao
    }
    META {
        uuid id PK
        uuid paciente_id FK
        int metrica_id FK "ex.: GORDURA_PCT"
        numeric valor_alvo
        date data_inicio
        date prazo
        text status "ATIVA, ATINGIDA, CANCELADA"
    }
```

## 3. Avaliação corporal e evolução (requisito 3)

Cada valor do laudo vira uma linha em `AVALIACAO_RESULTADO`. Com `regiao_id` nulo, é o valor do corpo inteiro; preenchido, é o valor do segmento. O laudo Relaxmedic de 08/10 inteiro cabe em 49 linhas. Peso e altura ficam em colunas da avaliação porque são obrigatórios e o IMC é calculado a partir deles. A view `vw_evolucao` junta tudo, inclusive exames, numa série única pra gráficos e comparações.

```mermaid
erDiagram
    PACIENTE ||--o{ AVALIACAO : realiza
    CONSULTA |o--o{ AVALIACAO : gera
    EQUIPAMENTO |o--o{ AVALIACAO : "medida com"
    AVALIACAO ||--o{ AVALIACAO_RESULTADO : contem
    METRICA ||--o{ AVALIACAO_RESULTADO : mede
    REGIAO_CORPORAL |o--o{ AVALIACAO_RESULTADO : "segmento de"

    AVALIACAO {
        uuid id PK
        uuid nutricionista_id FK
        uuid paciente_id FK
        uuid consulta_id FK "opcional, mesmo paciente"
        int equipamento_id FK
        text metodo "BIOIMPEDANCIA, ANTROPOMETRIA, MISTA"
        timestamptz data_hora_medicao
        numeric peso_kg
        numeric altura_cm
        numeric imc "gerado: peso / (altura/100)²"
        bool em_jejum
        text laudo_url "PDF ou foto do laudo"
    }
    AVALIACAO_RESULTADO {
        uuid id PK
        uuid avaliacao_id FK
        int metrica_id FK
        int regiao_id FK "nulo = corpo inteiro"
        numeric valor
        numeric ref_min "faixa do laudo"
        numeric ref_max
        text classificacao "rótulo do aparelho"
    }
    METRICA {
        int id PK
        text codigo UK "GORDURA_PCT, AGUA_CORPORAL_KG, IMPEDANCIA_20KHZ..."
        text nome
        text unidade
        text categoria "COMPOSICAO, SEGMENTAR, IMPEDANCIA, PERIMETRO, DOBRA_CUTANEA, LABORATORIAL..."
        smallint casas_decimais
    }
    REGIAO_CORPORAL {
        int id PK
        text codigo UK "BRACO_DIR, TRONCO, CINTURA, DC_TRICIPITAL..."
        text nome
        text tipo "SEGMENTO, PERIMETRO, DOBRA"
    }
    EQUIPAMENTO {
        int id PK
        uuid nutricionista_id FK "nulo = catálogo do sistema"
        text tipo "BIOIMPEDANCIA, ADIPOMETRO, FITA..."
        text marca
        text modelo
    }
```

## 4. Dieta e alimentos (requisito 5)

```mermaid
erDiagram
    NUTRICIONISTA ||--o{ DIETA : prescreve
    PACIENTE |o--o{ DIETA : segue
    CONSULTA |o--o{ DIETA : gera
    DIETA |o--o{ DIETA : "origina (modelo ou versão)"
    DIETA ||--o{ REFEICAO : contem
    REFEICAO ||--o{ REFEICAO_ITEM : contem
    ALIMENTO ||--o{ REFEICAO_ITEM : compoe
    ALIMENTO_MEDIDA |o--o{ REFEICAO_ITEM : "medida usada"
    REFEICAO_ITEM ||--o{ REFEICAO_ITEM_SUBSTITUTO : "pode trocar por"
    ALIMENTO ||--o{ REFEICAO_ITEM_SUBSTITUTO : ""
    GRUPO_ALIMENTAR |o--o{ ALIMENTO : agrupa
    ALIMENTO ||--o{ ALIMENTO_MEDIDA : "medidas caseiras"
    ALIMENTO ||--o{ ALIMENTO_NUTRIENTE : contem
    NUTRIENTE ||--o{ ALIMENTO_NUTRIENTE : ""
    CONDICAO ||--o{ CONDICAO_RESTRICAO : restringe
    ALIMENTO |o--o{ CONDICAO_RESTRICAO : ""
    GRUPO_ALIMENTAR |o--o{ CONDICAO_RESTRICAO : ""

    DIETA {
        uuid id PK
        uuid nutricionista_id FK
        uuid paciente_id FK "nulo = modelo"
        uuid consulta_id FK
        uuid dieta_origem_id FK
        bool is_modelo
        text titulo
        text objetivo
        numeric kcal_meta
        numeric proteina_meta_g
        numeric carboidrato_meta_g
        numeric lipidio_meta_g
        date data_inicio
        date data_fim
        text status "RASCUNHO, ATIVA, ENCERRADA"
    }
    REFEICAO {
        uuid id PK
        uuid dieta_id FK
        text nome "Café da manhã"
        time horario
        smallint ordem
        array dias_semana "1 = segunda ... 7 = domingo"
    }
    REFEICAO_ITEM {
        uuid id PK
        uuid refeicao_id FK
        int alimento_id FK
        smallint opcao "Opção 1, Opção 2"
        numeric quantidade "na medida escolhida"
        int alimento_medida_id FK "nulo = gramas"
        numeric quantidade_g "base dos cálculos"
    }
    REFEICAO_ITEM_SUBSTITUTO {
        uuid id PK
        uuid refeicao_item_id FK
        int alimento_id FK
        numeric quantidade
        int alimento_medida_id FK
        numeric quantidade_g
    }
    ALIMENTO {
        int id PK
        uuid nutricionista_id FK "nulo = TACO ou TBCA"
        int grupo_alimentar_id FK
        text nome
        text fonte "TACO, TBCA, PROPRIO"
        numeric porcao_base_g
        numeric kcal
        numeric proteina_g
        numeric carboidrato_g
        numeric lipidio_g
        numeric fibra_g
    }
    ALIMENTO_MEDIDA {
        int id PK
        int alimento_id FK
        text descricao "1 colher de sopa cheia"
        numeric gramas
    }
    NUTRIENTE {
        int id PK
        text nome UK
        text unidade
        numeric vd_referencia "%VD é calculado"
    }
    ALIMENTO_NUTRIENTE {
        int alimento_id PK, FK
        int nutriente_id PK, FK
        numeric quantidade "na porção base"
    }
    GRUPO_ALIMENTAR {
        int id PK
        text nome UK
    }
    CONDICAO_RESTRICAO {
        int id PK
        int condicao_id FK
        int alimento_id FK "ou grupo"
        int grupo_alimentar_id FK
    }
```

## 5. Exames (requisito 6)

```mermaid
erDiagram
    PACIENTE ||--o{ EXAME : apresenta
    CONSULTA |o--o{ EXAME : "trazido em"
    EXAME ||--o{ EXAME_ANEXO : anexa
    EXAME ||--o{ EXAME_RESULTADO : contem
    METRICA ||--o{ EXAME_RESULTADO : mede

    EXAME {
        uuid id PK
        uuid nutricionista_id FK
        uuid paciente_id FK
        uuid consulta_id FK "opcional"
        text nome "Perfil lipídico"
        text laboratorio
        date data_coleta
        text observacao
    }
    EXAME_ANEXO {
        uuid id PK
        uuid exame_id FK
        text storage_key "arquivo no S3, não no banco"
        text nome_arquivo
        text mime_type
        bigint tamanho_bytes
    }
    EXAME_RESULTADO {
        uuid id PK
        uuid exame_id FK
        int metrica_id FK "GLICEMIA_JEJUM, HDL, VITAMINA_D..."
        numeric valor
        numeric ref_min
        numeric ref_max
    }
```
