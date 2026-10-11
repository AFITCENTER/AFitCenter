# database/

Modelo de referência do banco, num esquema único (PostgreSQL 15+), usado na modelagem e validado com dados reais de bioimpedância.

- [01_schema.sql](01_schema.sql): todas as tabelas, num só banco.
- [02_seed_catalogos.sql](02_seed_catalogos.sql): catálogos (métricas, regiões corporais, condições, grupos alimentares, nutrientes).

**O esquema que roda está nas migrações Flyway de cada microsserviço** (`backend/ms-*/src/main/resources/db/migration`). Lá o modelo está dividido por serviço, com réplicas no lugar das FKs entre serviços. As diferenças estão em [docs/ARQUITETURA.md](../docs/ARQUITETURA.md#diferenças-em-relação-ao-mer).
