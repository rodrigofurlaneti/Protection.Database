# 🏦 Sistema Protection — Modelagem de Banco de Dados MySQL

> Documentação completa do modelo relacional (MER), função de cada tabela, relacionamentos, regras de negócio, triggers, procedures e views.

---

## 📋 Sumário

1. [Visão Geral](#visão-geral)
2. [Diagrama de Relacionamentos (MER)](#diagrama-de-relacionamentos-mer)
3. [Grupos de Tabelas](#grupos-de-tabelas)
4. [Descrição Detalhada de Cada Tabela](#descrição-detalhada-de-cada-tabela)
5. [Relacionamentos Completos](#relacionamentos-completos)
6. [Regras de Negócio Implementadas](#regras-de-negócio-implementadas)
7. [Triggers](#triggers)
8. [Stored Procedures](#stored-procedures)
9. [Views](#views)
10. [Índices de Desempenho](#índices-de-desempenho)
11. [Como Executar](#como-executar)

---

## Visão Geral

Este modelo cobre o ciclo de vida completo da Protection, desde o cadastro de clientes e emissão de apólices até o pagamento de sinistros, controle de comissões, resseguro e auditoria. São **24 tabelas**, **4 triggers**, **3 stored procedures**, **3 views** e um conjunto de índices otimizados.

| Componente | Quantidade |
|---|---|
| Tabelas | 24 |
| Triggers | 4 |
| Stored Procedures | 3 |
| Views | 3 |
| Índices extras | 9 |
| Constraints de negócio (CHECK) | 30+ |

---

## Diagrama de Relacionamentos (MER)

O diagrama abaixo representa as entidades e seus relacionamentos em notação textual. Leia `||--o{` como **"um para muitos"** e `||--||` como **"um para um"**.

```
endereco ||--o{ pessoa : "possui"

pessoa ||--|| cliente        : "é um"
pessoa ||--|| corretor       : "é um"
pessoa ||--|| perito         : "é um"
pessoa ||--|| usuario        : "é um"
pessoa ||--o{ beneficiario   : "designado como"

cliente   ||--o{ apolice     : "contrata"
corretor  ||--o{ apolice     : "intermedia"
produto   ||--o{ apolice     : "origina"
apolice   ||--o{ apolice     : "renovação (auto-ref)"

ramo      ||--o{ produto     : "classifica"
produto   ||--o{ cobertura   : "oferece"

apolice   ||--o{ apolice_cobertura  : "contém"
cobertura ||--o{ apolice_cobertura  : "incluída em"

apolice   ||--o{ beneficiario : "tem"
apolice   ||--o{ parcela      : "gera"
apolice   ||--o{ sinistro     : "origina"
apolice   ||--o{ comissao     : "gera"
apolice   ||--|| analise_risco : "passa por"
apolice   ||--o{ resseguro    : "cedido via"

cobertura ||--o{ sinistro     : "acionada em"

sinistro  ||--o{ sinistro_documento : "anexa"
sinistro  ||--o{ sinistro_historico : "registra"
sinistro  ||--o{ pericia             : "gera"
sinistro  ||--|| indenizacao         : "resulta em"

perito    ||--o{ pericia      : "realiza"

ressegurador ||--o{ resseguro : "assume"

parcela   ||--o{ comissao     : "base de"
corretor  ||--o{ comissao     : "recebe"

cliente   ||--o{ reclamacao   : "abre"
apolice   ||--o{ reclamacao   : "relacionada"
sinistro  ||--o{ reclamacao   : "relacionada"

produto   ||--o{ tabela_preco        : "tarifada por"
tabela_preco ||--o{ tabela_preco_faixa : "dividida em"
```

---

## Grupos de Tabelas

O modelo está organizado em **7 grupos funcionais**:

```
┌─────────────────────────────────────────────────────────────────┐
│  GRUPO 1 — BASE CADASTRAL                                       │
│  endereco · pessoa · cliente · corretor · perito · usuario      │
├─────────────────────────────────────────────────────────────────┤
│  GRUPO 2 — CATÁLOGO DE PRODUTOS                                 │
│  ramo · produto · cobertura · tabela_preco · tabela_preco_faixa │
├─────────────────────────────────────────────────────────────────┤
│  GRUPO 3 — APÓLICE                                              │
│  apolice · apolice_cobertura · beneficiario · parcela           │
├─────────────────────────────────────────────────────────────────┤
│  GRUPO 4 — SINISTRO                                             │
│  sinistro · sinistro_documento · sinistro_historico             │
│  pericia · indenizacao                                          │
├─────────────────────────────────────────────────────────────────┤
│  GRUPO 5 — FINANCEIRO                                           │
│  comissao · resseguro · ressegurador                            │
├─────────────────────────────────────────────────────────────────┤
│  GRUPO 6 — SUBSCRIÇÃO E RISCO                                   │
│  analise_risco                                                  │
├─────────────────────────────────────────────────────────────────┤
│  GRUPO 7 — GOVERNANÇA                                           │
│  reclamacao · auditoria                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Descrição Detalhada de Cada Tabela

---

### 🗂️ GRUPO 1 — Base Cadastral

---

#### `endereco`
Armazena endereços de forma normalizada e reutilizável por qualquer entidade do sistema (clientes, corretores, peritos, etc.).

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | INT PK | Identificador único |
| `logradouro` | VARCHAR(200) | Rua, avenida, etc. |
| `numero` | VARCHAR(20) | Número do imóvel |
| `complemento` | VARCHAR(100) | Apto, sala, bloco (opcional) |
| `bairro` | VARCHAR(100) | Bairro |
| `cidade` | VARCHAR(100) | Município |
| `estado` | CHAR(2) | Sigla UF (ex.: SP) |
| `cep` | CHAR(8) | Somente dígitos, 8 caracteres |
| `pais` | VARCHAR(60) | Padrão: Brasil |

**Constraints:** CEP deve ter exatamente 8 dígitos numéricos; estado deve ter 2 letras maiúsculas.

---

#### `pessoa`
Cadastro unificado de **Pessoa Física (PF)** e **Pessoa Jurídica (PJ)**. Todas as entidades humanas ou empresariais do sistema referenciam esta tabela.

| Coluna | Tipo | Descrição |
|---|---|---|
| `tipo` | ENUM('PF','PJ') | Discriminador do tipo de pessoa |
| `nome` | VARCHAR(150) | Nome completo (PF) |
| `cpf` | CHAR(11) | Somente dígitos, único no sistema (PF) |
| `data_nascimento` | DATE | Obrigatório para PF |
| `razao_social` | VARCHAR(200) | Nome legal da empresa (PJ) |
| `cnpj` | CHAR(14) | Somente dígitos, único no sistema (PJ) |
| `email` | VARCHAR(150) | Contato principal obrigatório |
| `endereco_id` | FK | Referência à tabela `endereco` |

**Regras de negócio:**
- PF **obriga** CPF, nome e data de nascimento.
- PJ **obriga** CNPJ e razão social.
- CPF e CNPJ são únicos globalmente.

---

#### `cliente`
Representa o **segurado** — a pessoa que contrata o seguro. Estende `pessoa` com informações comerciais.

| Coluna | Tipo | Descrição |
|---|---|---|
| `pessoa_id` | FK UNIQUE | Um cliente é exatamente uma pessoa |
| `numero_cliente` | VARCHAR(20) UNIQUE | Código interno único gerado pela seguradora |
| `profissao` | VARCHAR(100) | Usada na análise de risco |
| `renda_mensal` | DECIMAL(12,2) | Renda declarada |
| `score_risco` | TINYINT (0–100) | Score de risco do cliente |
| `inadimplente` | TINYINT(1) | Flag de inadimplência ativa |

**Relacionamentos:**
- `cliente` → `pessoa` (1:1)
- `cliente` → `apolice` (1:N) — um cliente pode ter várias apólices

---

#### `corretor`
Profissional habilitado pela **SUSEP** que intermedia a venda de apólices.

| Coluna | Tipo | Descrição |
|---|---|---|
| `pessoa_id` | FK UNIQUE | Vínculo com cadastro de pessoa |
| `susep` | VARCHAR(20) UNIQUE | Registro obrigatório na SUSEP |
| `comissao_pct` | DECIMAL(5,2) | Percentual de comissão (0–30%) |
| `data_contrato` | DATE | Início do contrato com a seguradora |
| `data_rescisao` | DATE | Encerramento do vínculo (nullable) |

**Regras:** Data de rescisão não pode ser anterior à data de contrato.

---

#### `perito`
Profissional técnico responsável por avaliar e laudar sinistros.

| Coluna | Tipo | Descrição |
|---|---|---|
| `pessoa_id` | FK UNIQUE | Vínculo com cadastro de pessoa |
| `crea_crm` | VARCHAR(30) | Registro profissional (CREA, CRM, etc.) |
| `especialidade` | VARCHAR(100) | Área de atuação (ex.: Automóvel, Saúde) |

---

#### `usuario`
Operadores internos do sistema (analistas, caixas, auditores). Controla acesso e perfis.

| Coluna | Tipo | Descrição |
|---|---|---|
| `pessoa_id` | FK UNIQUE | Vínculo com cadastro de pessoa |
| `login` | VARCHAR(60) UNIQUE | Login de acesso |
| `senha_hash` | CHAR(60) | Hash bcrypt da senha |
| `perfil` | ENUM | ADMIN, ANALISTA, CORRETOR, CAIXA, AUDITOR, OUVIDORIA |
| `tentativas_falha` | TINYINT | Bloqueio após 5 tentativas falhas |
| `bloqueado` | TINYINT(1) | Flag de bloqueio de acesso |

---

### 🗂️ GRUPO 2 — Catálogo de Produtos

---

#### `ramo`
Classificação regulatória dos seguros, seguindo a nomenclatura da SUSEP (ex.: AUTO, VIDA, SAUDE).

| Coluna | Tipo | Descrição |
|---|---|---|
| `codigo` | VARCHAR(10) UNIQUE | Código interno do ramo |
| `nome` | VARCHAR(100) | Nome legível |

**Dados iniciais incluídos:** AUTO, VIDA, SAUDE, INCENDIO, VIAGEM, RC, RURAL.

---

#### `produto`
Define os **planos de seguro** comercializados. Cada produto pertence a um ramo e tem limites financeiros próprios.

| Coluna | Tipo | Descrição |
|---|---|---|
| `ramo_id` | FK | Ramo ao qual pertence |
| `premio_minimo` / `maximo` | DECIMAL | Faixa de prêmio permitida |
| `limite_cobertura` | DECIMAL | Capital segurado máximo |
| `vigencia_meses` | TINYINT | Duração padrão (1–120 meses) |
| `renovacao_auto` | TINYINT(1) | Indica renovação automática |
| `franquia_padrao` | DECIMAL | Franquia padrão do produto |

---

#### `cobertura`
Coberturas disponíveis em cada produto. Podem ser básicas (obrigatórias), adicionais ou opcionais.

| Coluna | Tipo | Descrição |
|---|---|---|
| `produto_id` | FK | Produto ao qual pertence |
| `tipo` | ENUM | BASICA, ADICIONAL, OPCIONAL |
| `limite_valor` | DECIMAL | Valor máximo coberto |
| `franquia` | DECIMAL | Franquia específica da cobertura |
| `obrigatoria` | TINYINT(1) | Indica se é mandatória no contrato |

---

#### `tabela_preco`
Versão tarifária de um produto com vigência definida. Permite histórico de preços.

| Coluna | Tipo | Descrição |
|---|---|---|
| `produto_id` | FK | Produto tarifado |
| `vigencia_inicio` / `fim` | DATE | Período de validade da tabela |
| `ativa` | TINYINT(1) | Controle de qual versão está em uso |

---

#### `tabela_preco_faixa`
Faixas de capital segurado com suas respectivas taxas de prêmio percentuais.

| Coluna | Tipo | Descrição |
|---|---|---|
| `tabela_preco_id` | FK | Tabela a que pertence |
| `faixa_min` / `max` | DECIMAL | Intervalo de capital segurado |
| `taxa_pct` | DECIMAL(6,4) | % do prêmio sobre o capital |
| `agravo_pct` | DECIMAL(5,2) | Sobretaxa por risco agravado |

---

### 🗂️ GRUPO 3 — Apólice

---

#### `apolice`
**Entidade central do modelo.** Representa o contrato de seguro entre a seguradora e o cliente.

| Coluna | Tipo | Descrição |
|---|---|---|
| `numero` | VARCHAR(30) UNIQUE | Número oficial da apólice |
| `cliente_id` | FK | Segurado |
| `produto_id` | FK | Produto contratado |
| `corretor_id` | FK (nullable) | Corretor intermediador |
| `data_inicio` / `fim` | DATE | Período de vigência |
| `capital_segurado` | DECIMAL | Valor total assegurado |
| `premio_total` | DECIMAL | Prêmio cobrado (bruto) |
| `premio_liquido` | DECIMAL | Prêmio sem IOF/taxas |
| `iof` | DECIMAL | IOF calculado |
| `franquia` | DECIMAL | Franquia do contrato |
| `forma_pagamento` | ENUM | BOLETO, CARTAO, DEBITO, PIX |
| `num_parcelas` | TINYINT (1–12) | Número de parcelas |
| `status` | ENUM | Fluxo completo de status |
| `apolice_origem_id` | FK self-ref | Apólice que originou esta (renovação) |

**Fluxo de status:**
```
PROPOSTA → ANALISE → ATIVA → EXPIRADA
                   ↘ CANCELADA
                   ↘ SUSPENSA (inadimplência) → ATIVA (regularização)
                   ↘ RENOVADA (substituída por nova apólice)
```

---

#### `apolice_cobertura`
Tabela associativa que registra quais coberturas foram **efetivamente contratadas** em cada apólice, com os valores negociados.

| Coluna | Tipo | Descrição |
|---|---|---|
| `apolice_id` | FK | Apólice contratante |
| `cobertura_id` | FK | Cobertura incluída |
| `limite_valor` | DECIMAL | Limite acordado (pode diferir do padrão) |
| `franquia` | DECIMAL | Franquia específica negociada |
| `premio_adicional` | DECIMAL | Prêmio extra por esta cobertura |

**Constraint:** Par `(apolice_id, cobertura_id)` é único — não se repete a mesma cobertura.

---

#### `beneficiario`
Pessoas designadas para receber a indenização. Comuns em seguros de vida.

| Coluna | Tipo | Descrição |
|---|---|---|
| `apolice_id` | FK | Apólice a que pertence |
| `pessoa_id` | FK | Beneficiário (pessoa cadastrada) |
| `grau_parentesco` | VARCHAR | Ex.: cônjuge, filho |
| `percentual` | DECIMAL | % do capital a receber |
| `principal` | TINYINT(1) | Indica beneficiário principal |

**Trigger:** Impede que a soma dos percentuais de todos os beneficiários de uma apólice ultrapasse 100%.

---

#### `parcela`
Controla o pagamento mensal do prêmio da apólice.

| Coluna | Tipo | Descrição |
|---|---|---|
| `apolice_id` | FK | Apólice correspondente |
| `numero` | TINYINT | Sequência: 1, 2, 3... |
| `valor` | DECIMAL | Valor da parcela |
| `data_vencimento` | DATE | Data de vencimento |
| `data_pagamento` | DATE | Data em que foi paga (nullable) |
| `status` | ENUM | PENDENTE, PAGA, ATRASADA, CANCELADA |
| `nosso_numero` | VARCHAR | Referência bancária/boleto |

**Trigger:** Ao marcar parcela como `ATRASADA`, a apólice correspondente é automaticamente `SUSPENSA`.

---

### 🗂️ GRUPO 4 — Sinistro

---

#### `sinistro`
Registra o acionamento do seguro. É o ponto de partida do processo de indenização.

| Coluna | Tipo | Descrição |
|---|---|---|
| `numero` | VARCHAR(30) UNIQUE | Número do sinistro |
| `apolice_id` | FK | Apólice acionada |
| `cobertura_id` | FK | Cobertura específica acionada |
| `data_ocorrencia` | DATETIME | Quando o evento ocorreu (não pode ser futura) |
| `data_comunicacao` | DATETIME | Quando foi comunicado à seguradora |
| `valor_reclamado` | DECIMAL | Valor solicitado pelo segurado |
| `valor_pericia` | DECIMAL | Avaliação técnica do perito |
| `valor_aprovado` | DECIMAL | Valor aprovado pela seguradora |
| `franquia_aplicada` | DECIMAL | Franquia deduzida |
| `valor_indenizacao` | DECIMAL **GERADO** | `MAX(0, aprovado − franquia)` — calculado automaticamente |
| `status` | ENUM | Fluxo completo do sinistro |
| `terceiro_envolvido` | TINYINT(1) | Indica envolvimento de terceiros |

**Fluxo de status do sinistro:**
```
ABERTO → EM_PERICIA → AGUARDANDO_DOCUMENTOS → EM_ANALISE
       → APROVADO / PARCIALMENTE_APROVADO / NEGADO
       → PAGO
       → RECURSO (contestação do resultado)
       → CANCELADO
```

---

#### `sinistro_documento`
Anexos e comprovantes vinculados ao sinistro (BOs, notas fiscais, laudos médicos, fotos).

| Coluna | Tipo | Descrição |
|---|---|---|
| `sinistro_id` | FK | Sinistro ao qual pertence |
| `tipo` | ENUM | BO, NOTA_FISCAL, LAUDO_MEDICO, FOTO, VIDEO, etc. |
| `nome_arquivo` | VARCHAR | Nome original do arquivo |
| `caminho` | VARCHAR(500) | Caminho no storage |
| `enviado_por` | FK (pessoa) | Quem enviou o documento |

---

#### `sinistro_historico`
**Trilha de auditoria** de todas as mudanças de status do sinistro. Preenchida automaticamente via trigger.

| Coluna | Tipo | Descrição |
|---|---|---|
| `sinistro_id` | FK | Sinistro monitorado |
| `status_anterior` | VARCHAR | Status antes da mudança |
| `status_novo` | VARCHAR | Status após a mudança |
| `observacao` | TEXT | Comentário do operador |
| `usuario_id` | FK (pessoa) | Responsável pela alteração |

---

#### `pericia`
Agendamento e resultado da vistoria técnica realizada por um perito.

| Coluna | Tipo | Descrição |
|---|---|---|
| `sinistro_id` | FK | Sinistro avaliado |
| `perito_id` | FK | Perito designado |
| `data_agendada` | DATETIME | Data prevista para realização |
| `data_realizada` | DATETIME | Data efetiva (nullable) |
| `laudo` | TEXT | Texto completo do laudo técnico |
| `valor_estimado` | DECIMAL | Estimativa de dano do perito |
| `resultado` | ENUM | CONFIRMADO, PARCIAL, NEGADO, PENDENTE |

---

#### `indenizacao`
**Pagamento final** do sinistro ao beneficiário. Relação 1:1 com sinistro (um sinistro gera no máximo uma indenização).

| Coluna | Tipo | Descrição |
|---|---|---|
| `sinistro_id` | FK UNIQUE | Sinistro liquidado |
| `valor_bruto` | DECIMAL | Valor antes de impostos |
| `imposto_retido` | DECIMAL | IR ou outros tributos retidos |
| `valor_liquido` | DECIMAL | Valor efetivamente pago |
| `forma_pagamento` | ENUM | TED, PIX, BOLETO, CHEQUE |
| `chave_pix` | VARCHAR | Chave para pagamentos via PIX |
| `data_aprovacao` | DATE | Data da aprovação do pagamento |
| `data_pagamento` | DATE | Data da liquidação |
| `status` | ENUM | AGUARDANDO, PROCESSANDO, PAGO, ESTORNADO |
| `comprovante` | VARCHAR | Caminho do comprovante de pagamento |

---

### 🗂️ GRUPO 5 — Financeiro

---

#### `comissao`
Controla os valores devidos e pagos a cada corretor, por apólice e parcela.

| Coluna | Tipo | Descrição |
|---|---|---|
| `corretor_id` | FK | Corretor beneficiário |
| `apolice_id` | FK | Apólice de origem |
| `parcela_id` | FK (nullable) | Parcela de origem (se comissão parcelada) |
| `valor_base` | DECIMAL | Base de cálculo |
| `percentual` | DECIMAL (0–30%) | Alíquota de comissão |
| `valor_comissao` | DECIMAL | Valor calculado |
| `competencia` | DATE | Mês/ano de referência |
| `status` | ENUM | PENDENTE, PAGA, ESTORNADA |

---

#### `ressegurador`
Cadastro das empresas resseguradoras parceiras (reguladas pela SUSEP).

| Coluna | Tipo | Descrição |
|---|---|---|
| `cnpj` | CHAR(14) UNIQUE | CNPJ da resseguradora |
| `susep` | VARCHAR(20) UNIQUE | Registro SUSEP da resseguradora |

---

#### `resseguro`
Cessão de risco de uma apólice a uma resseguradora. Garante cobertura para sinistros de alto valor.

| Coluna | Tipo | Descrição |
|---|---|---|
| `apolice_id` | FK | Apólice cedida |
| `ressegurador_id` | FK | Resseguradora receptora |
| `percentual_cede` | DECIMAL (0–100%) | % do risco cedido |
| `premio_cedido` | DECIMAL | Prêmio repassado à resseguradora |
| `vigencia_inicio` / `fim` | DATE | Período de cobertura |

---

### 🗂️ GRUPO 6 — Subscrição e Risco

---

#### `analise_risco`
Parecer técnico da área de subscrição antes da emissão da apólice. Relação 1:1 com apólice.

| Coluna | Tipo | Descrição |
|---|---|---|
| `apolice_id` | FK UNIQUE | Apólice analisada |
| `analista_id` | FK (usuario) | Analista responsável |
| `score_risco` | TINYINT (0–100) | Score calculado pelo subscritor |
| `fatores` | JSON | Fatores de risco detalhados |
| `parecer` | ENUM | APROVADO, APROVADO_COM_RESTRICOES, RECUSADO |
| `carencia_dias` | SMALLINT (0–730) | Período de carência imposto |

**Regra:** A SP `sp_emitir_apolice` exige parecer `APROVADO` ou `APROVADO_COM_RESTRICOES` antes de ativar a apólice.

---

### 🗂️ GRUPO 7 — Governança

---

#### `reclamacao`
Registro de reclamações formais e ouvidoria, inclusive as encaminhadas à SUSEP.

| Coluna | Tipo | Descrição |
|---|---|---|
| `numero_protocolo` | VARCHAR UNIQUE | Protocolo de atendimento |
| `cliente_id` | FK | Cliente reclamante |
| `apolice_id` | FK (nullable) | Apólice envolvida |
| `sinistro_id` | FK (nullable) | Sinistro envolvido |
| `canal` | ENUM | TELEFONE, EMAIL, CHAT, PRESENCIAL, SUSEP |
| `prazo_resposta` | DATE | SLA de resposta ao cliente |
| `status` | ENUM | ABERTA → EM_ANALISE → RESOLVIDA / IMPROCEDENTE / ESCALADA |

---

#### `auditoria`
Log centralizado de todas as operações críticas no banco de dados.

| Coluna | Tipo | Descrição |
|---|---|---|
| `tabela` | VARCHAR | Tabela onde a operação ocorreu |
| `registro_id` | INT | ID do registro afetado |
| `operacao` | ENUM | INSERT, UPDATE, DELETE |
| `dados_antes` | JSON | Estado anterior do registro |
| `dados_depois` | JSON | Estado posterior do registro |
| `usuario` | VARCHAR | Login do operador |
| `ip_origem` | VARCHAR | IP de origem da operação |

---

## Relacionamentos Completos

| Tabela Origem | Coluna | Tabela Destino | Cardinalidade | Descrição |
|---|---|---|---|---|
| `pessoa` | `endereco_id` | `endereco` | N:1 | Toda pessoa tem um endereço |
| `cliente` | `pessoa_id` | `pessoa` | 1:1 | Cliente é uma especialização de pessoa |
| `corretor` | `pessoa_id` | `pessoa` | 1:1 | Corretor é uma especialização de pessoa |
| `perito` | `pessoa_id` | `pessoa` | 1:1 | Perito é uma especialização de pessoa |
| `usuario` | `pessoa_id` | `pessoa` | 1:1 | Usuário é uma especialização de pessoa |
| `produto` | `ramo_id` | `ramo` | N:1 | Produto pertence a um ramo |
| `cobertura` | `produto_id` | `produto` | N:1 | Cobertura pertence a um produto |
| `tabela_preco` | `produto_id` | `produto` | N:1 | Tabela de preço é de um produto |
| `tabela_preco_faixa` | `tabela_preco_id` | `tabela_preco` | N:1 | Faixas de uma tabela |
| `apolice` | `cliente_id` | `cliente` | N:1 | Apólice pertence a um cliente |
| `apolice` | `produto_id` | `produto` | N:1 | Apólice é de um produto |
| `apolice` | `corretor_id` | `corretor` | N:1 (opt) | Apólice pode ter corretor |
| `apolice` | `apolice_origem_id` | `apolice` | N:1 (self) | Auto-referência para renovações |
| `apolice_cobertura` | `apolice_id` | `apolice` | N:1 | Associativa apólice-cobertura |
| `apolice_cobertura` | `cobertura_id` | `cobertura` | N:1 | Associativa apólice-cobertura |
| `beneficiario` | `apolice_id` | `apolice` | N:1 | Beneficiários de uma apólice |
| `beneficiario` | `pessoa_id` | `pessoa` | N:1 | Beneficiário é uma pessoa |
| `parcela` | `apolice_id` | `apolice` | N:1 | Parcelas de uma apólice |
| `sinistro` | `apolice_id` | `apolice` | N:1 | Sinistro gerado por uma apólice |
| `sinistro` | `cobertura_id` | `cobertura` | N:1 | Cobertura acionada |
| `sinistro` | `responsavel_id` | `pessoa` | N:1 (opt) | Analista responsável |
| `sinistro_documento` | `sinistro_id` | `sinistro` | N:1 | Docs de um sinistro |
| `sinistro_historico` | `sinistro_id` | `sinistro` | N:1 | Histórico de um sinistro |
| `pericia` | `sinistro_id` | `sinistro` | N:1 | Perícias de um sinistro |
| `pericia` | `perito_id` | `perito` | N:1 | Perito que realizou a perícia |
| `indenizacao` | `sinistro_id` | `sinistro` | 1:1 | Indenização de um sinistro |
| `comissao` | `corretor_id` | `corretor` | N:1 | Comissões de um corretor |
| `comissao` | `apolice_id` | `apolice` | N:1 | Comissões de uma apólice |
| `comissao` | `parcela_id` | `parcela` | N:1 (opt) | Comissão vinculada a parcela |
| `resseguro` | `apolice_id` | `apolice` | N:1 | Apólice ressegurada |
| `resseguro` | `ressegurador_id` | `ressegurador` | N:1 | Resseguradora receptora |
| `analise_risco` | `apolice_id` | `apolice` | 1:1 | Análise de uma apólice |
| `analise_risco` | `analista_id` | `usuario` | N:1 | Analista que realizou |
| `reclamacao` | `cliente_id` | `cliente` | N:1 | Reclamação de um cliente |
| `reclamacao` | `apolice_id` | `apolice` | N:1 (opt) | Apólice envolvida |
| `reclamacao` | `sinistro_id` | `sinistro` | N:1 (opt) | Sinistro envolvido |

---

## Regras de Negócio Implementadas

### Cadastro
- CPF deve ter exatamente 11 dígitos numéricos; CNPJ, 14.
- CPF e CNPJ são únicos no sistema.
- Pessoa Física **exige** CPF, nome e data de nascimento.
- Pessoa Jurídica **exige** CNPJ e razão social.
- CEP deve ter exatamente 8 dígitos numéricos.
- Estado deve ter exatamente 2 letras maiúsculas.
- Corretor deve ter registro SUSEP válido e único.
- Percentual de comissão do corretor deve estar entre 0% e 30%.

### Produto e Tarifação
- Prêmio mínimo deve ser maior que zero; máximo deve ser maior ou igual ao mínimo.
- Vigência do produto deve ser entre 1 e 120 meses.
- Limite de cobertura deve ser maior que zero.

### Apólice
- Data de fim da vigência deve ser posterior à data de início.
- Capital segurado e prêmio total devem ser maiores que zero.
- IOF e franquia não podem ser negativos.
- Número de parcelas deve estar entre 1 e 12.
- A emissão (ativação) exige análise de risco aprovada.
- Renovação registra a apólice de origem via `apolice_origem_id`.

### Beneficiários
- Soma dos percentuais de todos os beneficiários de uma apólice não pode exceder 100% (via trigger).

### Parcelas e Inadimplência
- Parcela com status `ATRASADA` suspende automaticamente a apólice (via trigger).
- Valor da parcela deve ser maior que zero.
- Par `(apolice_id, numero)` é único — não existem duas parcelas com o mesmo número para a mesma apólice.

### Sinistro
- Data de ocorrência não pode ser futura.
- Data de comunicação não pode ser anterior à data de ocorrência.
- Valor reclamado deve ser maior que zero.
- A cobertura acionada deve estar contratada na apólice (verificado pela SP).
- A apólice deve estar ativa para aceitar sinistro (verificado pela SP).
- `valor_indenizacao` é calculado automaticamente: `MAX(0, valor_aprovado − franquia_aplicada)`.

### Análise de Risco
- Score de risco deve estar entre 0 e 100.
- Período de carência não pode exceder 730 dias (2 anos).

### Resseguro
- Percentual cedido deve estar entre 0% e 100%.
- Vigência do resseguro deve ser consistente (fim > início).

---

## Triggers

| Nome | Tabela | Evento | Ação |
|---|---|---|---|
| `trg_beneficiario_percentual_bi` | `beneficiario` | BEFORE INSERT | Impede inserção se soma dos percentuais ultrapassar 100% |
| `trg_parcela_atraso_bu` | `parcela` | BEFORE UPDATE | Suspende apólice quando parcela vai para status ATRASADA |
| `trg_sinistro_historico_au` | `sinistro` | AFTER UPDATE | Grava automaticamente o histórico quando o status muda |

---

## Stored Procedures

### `sp_emitir_apolice(p_apolice_id, p_usuario_id)`
Ativa uma apólice que estava em análise.

**Validações internas:**
1. Verifica se a apólice está com status `ANALISE`.
2. Verifica se existe análise de risco com parecer `APROVADO` ou `APROVADO_COM_RESTRICOES`.
3. Atualiza o status para `ATIVA`.
4. Grava registro na tabela de auditoria.

---

### `sp_registrar_sinistro(p_apolice_id, p_cobertura_id, p_data_ocorrencia, p_descricao, p_valor_reclamado, OUT p_sinistro_id)`
Abre um novo sinistro com todas as validações necessárias.

**Validações internas:**
1. Verifica se a apólice está `ATIVA`.
2. Verifica se a cobertura está contratada na apólice (via `apolice_cobertura`).
3. Gera número único do sinistro no formato `SIN-YYYYMM-NNNNNN`.
4. Retorna o ID do sinistro criado via parâmetro OUT.

---

### `sp_calcular_premio(p_produto_id, p_capital_segurado, OUT p_premio)`
Calcula o prêmio consultando a tabela de tarifas vigente.

**Lógica:**
1. Busca a tabela de preço ativa para o produto informado.
2. Localiza a faixa tarifária correspondente ao capital segurado.
3. Calcula: `prêmio = capital_segurado × taxa_pct / 100`.
4. Retorna o valor calculado arredondado a 2 casas decimais.

---

## Views

### `vw_apolices_ativas`
Visão consolidada das apólices ativas com dados do cliente, produto, ramo, corretor e dias restantes para vencer.

```sql
SELECT * FROM vw_apolices_ativas WHERE dias_para_vencer <= 30;
-- Lista apólices a vencer em 30 dias (candidatas à renovação)
```

---

### `vw_sinistros_abertos`
Sinistros em andamento com valores e tempo de abertura em dias.

```sql
SELECT * FROM vw_sinistros_abertos WHERE dias_aberto > 15 ORDER BY valor_reclamado DESC;
-- Sinistros críticos: abertos há mais de 15 dias com maior valor
```

---

### `vw_parcelas_vencidas`
Parcelas pendentes com data vencida, ordenadas por atraso. Base para gestão de inadimplência.

```sql
SELECT * FROM vw_parcelas_vencidas WHERE dias_atraso > 30;
-- Inadimplência acima de 30 dias
```

---

## Índices de Desempenho

| Índice | Tabela | Colunas | Finalidade |
|---|---|---|---|
| `idx_apolice_cliente` | `apolice` | `cliente_id` | Busca de apólices por cliente |
| `idx_apolice_status` | `apolice` | `status` | Filtro por status |
| `idx_apolice_vigencia` | `apolice` | `data_inicio, data_fim` | Consultas de vigência |
| `idx_parcela_vencimento` | `parcela` | `data_vencimento, status` | Cobrança e inadimplência |
| `idx_sinistro_status` | `sinistro` | `status` | Triagem de sinistros |
| `idx_sinistro_apolice` | `sinistro` | `apolice_id` | Sinistros por apólice |
| `idx_pessoa_cpf` | `pessoa` | `cpf` | Busca por CPF |
| `idx_pessoa_cnpj` | `pessoa` | `cnpj` | Busca por CNPJ |
| `idx_comissao_corretor` | `comissao` | `corretor_id, competencia` | Fechamento mensal de comissões |
| `idx_aud_tabela` | `auditoria` | `tabela` | Auditoria por entidade |
| `idx_aud_registro` | `auditoria` | `tabela, registro_id` | Histórico de um registro |
| `idx_aud_data` | `auditoria` | `criado_em` | Auditoria por período |

---

## Como Executar

### Pré-requisitos
- MySQL 8.0 ou superior (necessário para colunas geradas e JSON nativo)
- Usuário com permissão `CREATE`, `ALTER`, `TRIGGER`, `PROCEDURE`

### Passo a passo

```bash
# 1. Criar o schema
mysql -u root -p -e "CREATE DATABASE seguradora CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 2. Executar o script completo
mysql -u root -p seguradora < seguradora_completo.sql

# 3. Verificar as tabelas criadas
mysql -u root -p seguradora -e "SHOW TABLES;"
```

### Ordem de dependências (caso precise executar em partes)

```
endereco
  └─ pessoa
       ├─ cliente
       ├─ corretor
       ├─ perito
       └─ usuario

ramo
  └─ produto
       ├─ cobertura
       └─ tabela_preco
            └─ tabela_preco_faixa

cliente + produto + corretor
  └─ apolice
       ├─ apolice_cobertura
       ├─ beneficiario
       ├─ parcela
       ├─ sinistro
       │    ├─ sinistro_documento
       │    ├─ sinistro_historico
       │    ├─ pericia
       │    └─ indenizacao
       ├─ comissao
       ├─ resseguro
       └─ analise_risco

cliente + apolice + sinistro
  └─ reclamacao

(qualquer tabela)
  └─ auditoria
```

---

*Documentação gerada para o script `seguradora_completo.sql` — versão 1.0*
