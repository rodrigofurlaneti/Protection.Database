-- ============================================================
--  SISTEMA Protection - MODELAGEM COMPLETA MySQL
--  Versão: 1.0 | Autor: 
--  Cobertura: Clientes, Apólices, Sinistros, Pagamentos,
--              Corretores, Produtos, Reembolsos e Auditoria
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- ============================================================
-- 1. ENDEREÇOS (tabela base reutilizada por várias entidades)
-- ============================================================
CREATE TABLE IF NOT EXISTS endereco (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    logradouro      VARCHAR(200)    NOT NULL,
    numero          VARCHAR(20)     NOT NULL,
    complemento     VARCHAR(100),
    bairro          VARCHAR(100)    NOT NULL,
    cidade          VARCHAR(100)    NOT NULL,
    estado          CHAR(2)         NOT NULL,
    cep             CHAR(8)         NOT NULL,         -- somente dígitos
    pais            VARCHAR(60)     NOT NULL DEFAULT 'Brasil',
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_estado   CHECK (estado REGEXP '^[A-Z]{2}$'),
    CONSTRAINT chk_cep      CHECK (cep    REGEXP '^[0-9]{8}$')
) ENGINE=InnoDB COMMENT='Endereços normalizados';

-- ============================================================
-- 2. PESSOAS (pessoa física e jurídica unificadas)
-- ============================================================
CREATE TABLE IF NOT EXISTS pessoa (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo            ENUM('PF','PJ')  NOT NULL,
    -- Pessoa Física
    nome            VARCHAR(150),
    cpf             CHAR(11),          -- somente dígitos
    rg              VARCHAR(20),
    data_nascimento DATE,
    sexo            ENUM('M','F','O'),
    -- Pessoa Jurídica
    razao_social    VARCHAR(200),
    nome_fantasia   VARCHAR(200),
    cnpj            CHAR(14),          -- somente dígitos
    inscricao_estadual VARCHAR(20),
    -- Contato
    email           VARCHAR(150)    NOT NULL,
    telefone        VARCHAR(15),
    celular         VARCHAR(15),
    -- Endereço
    endereco_id     INT UNSIGNED    NOT NULL,
    -- Controle
    ativo           TINYINT(1)      NOT NULL DEFAULT 1,
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_pessoa_endereco   FOREIGN KEY (endereco_id) REFERENCES endereco(id),
    CONSTRAINT uq_cpf               UNIQUE (cpf),
    CONSTRAINT uq_cnpj              UNIQUE (cnpj),
    CONSTRAINT chk_cpf_len          CHECK (cpf  IS NULL OR LENGTH(cpf)  = 11),
    CONSTRAINT chk_cnpj_len         CHECK (cnpj IS NULL OR LENGTH(cnpj) = 14),
    -- PF deve ter CPF e nome; PJ deve ter CNPJ e razão social
    CONSTRAINT chk_pf_campos CHECK (
        tipo <> 'PF' OR (cpf IS NOT NULL AND nome IS NOT NULL AND data_nascimento IS NOT NULL)
    ),
    CONSTRAINT chk_pj_campos CHECK (
        tipo <> 'PJ' OR (cnpj IS NOT NULL AND razao_social IS NOT NULL)
    )
) ENGINE=InnoDB COMMENT='Cadastro unificado PF/PJ';

-- ============================================================
-- 3. CORRETORES
-- ============================================================
CREATE TABLE IF NOT EXISTS corretor (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id       INT UNSIGNED    NOT NULL,
    susep           VARCHAR(20)     NOT NULL UNIQUE,   -- registro SUSEP obrigatório
    comissao_pct    DECIMAL(5,2)    NOT NULL DEFAULT 5.00,  -- % de comissão
    data_contrato   DATE            NOT NULL,
    data_rescisao   DATE,
    ativo           TINYINT(1)      NOT NULL DEFAULT 1,
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_corretor_pessoa   FOREIGN KEY (pessoa_id) REFERENCES pessoa(id),
    CONSTRAINT chk_comissao         CHECK (comissao_pct BETWEEN 0 AND 30),
    CONSTRAINT chk_rescisao_corretor CHECK (data_rescisao IS NULL OR data_rescisao >= data_contrato)
) ENGINE=InnoDB COMMENT='Corretores de seguros com registro SUSEP';

-- ============================================================
-- 4. RAMOS / CATEGORIAS DE SEGURO
-- ============================================================
CREATE TABLE IF NOT EXISTS ramo (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo          VARCHAR(10)     NOT NULL UNIQUE,   -- ex.: AUTO, VIDA, SAUDE, INCENDIO
    nome            VARCHAR(100)    NOT NULL,
    descricao       TEXT,
    ativo           TINYINT(1)      NOT NULL DEFAULT 1
) ENGINE=InnoDB COMMENT='Ramos de seguro (ex.: Auto, Vida, Saúde)';

-- ============================================================
-- 5. PRODUTOS (apólice-base)
-- ============================================================
CREATE TABLE IF NOT EXISTS produto (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ramo_id             INT UNSIGNED    NOT NULL,
    codigo              VARCHAR(20)     NOT NULL UNIQUE,
    nome                VARCHAR(150)    NOT NULL,
    descricao           TEXT,
    -- Limites financeiros do produto
    premio_minimo       DECIMAL(12,2)   NOT NULL,
    premio_maximo       DECIMAL(12,2)   NOT NULL,
    franquia_padrao     DECIMAL(12,2)   NOT NULL DEFAULT 0,
    limite_cobertura    DECIMAL(15,2)   NOT NULL,   -- capital segurado máximo
    -- Vigência padrão
    vigencia_meses      TINYINT UNSIGNED NOT NULL DEFAULT 12,
    -- Renovação automática
    renovacao_auto      TINYINT(1)      NOT NULL DEFAULT 0,
    ativo               TINYINT(1)      NOT NULL DEFAULT 1,
    criado_em           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_produto_ramo      FOREIGN KEY (ramo_id) REFERENCES ramo(id),
    CONSTRAINT chk_premio_range     CHECK (premio_minimo > 0 AND premio_maximo >= premio_minimo),
    CONSTRAINT chk_limite_cob       CHECK (limite_cobertura > 0),
    CONSTRAINT chk_vigencia         CHECK (vigencia_meses BETWEEN 1 AND 120)
) ENGINE=InnoDB COMMENT='Produtos/planos de seguro';

-- ============================================================
-- 6. COBERTURAS DO PRODUTO
-- ============================================================
CREATE TABLE IF NOT EXISTS cobertura (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    produto_id      INT UNSIGNED    NOT NULL,
    nome            VARCHAR(150)    NOT NULL,
    descricao       TEXT,
    tipo            ENUM('BASICA','ADICIONAL','OPCIONAL') NOT NULL DEFAULT 'BASICA',
    limite_valor    DECIMAL(15,2)   NOT NULL,
    franquia        DECIMAL(12,2)   NOT NULL DEFAULT 0,
    obrigatoria     TINYINT(1)      NOT NULL DEFAULT 0,
    ativo           TINYINT(1)      NOT NULL DEFAULT 1,

    CONSTRAINT fk_cobertura_produto FOREIGN KEY (produto_id) REFERENCES produto(id),
    CONSTRAINT chk_cob_limite       CHECK (limite_valor > 0)
) ENGINE=InnoDB COMMENT='Coberturas disponíveis por produto';

-- ============================================================
-- 7. CLIENTES (segurados)
-- ============================================================
CREATE TABLE IF NOT EXISTS cliente (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id       INT UNSIGNED    NOT NULL UNIQUE,
    numero_cliente  VARCHAR(20)     NOT NULL UNIQUE,  -- código interno
    profissao       VARCHAR(100),
    renda_mensal    DECIMAL(12,2),
    score_risco     TINYINT UNSIGNED NOT NULL DEFAULT 50, -- 0-100
    inadimplente    TINYINT(1)      NOT NULL DEFAULT 0,
    data_cadastro   DATE            NOT NULL,
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_cliente_pessoa    FOREIGN KEY (pessoa_id) REFERENCES pessoa(id),
    CONSTRAINT chk_score_risco      CHECK (score_risco BETWEEN 0 AND 100)
) ENGINE=InnoDB COMMENT='Segurados/clientes da seguradora';

-- ============================================================
-- 8. APÓLICES
-- ============================================================
CREATE TABLE IF NOT EXISTS apolice (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero              VARCHAR(30)     NOT NULL UNIQUE,  -- nº oficial da apólice
    cliente_id          INT UNSIGNED    NOT NULL,
    produto_id          INT UNSIGNED    NOT NULL,
    corretor_id         INT UNSIGNED,
    -- Vigência
    data_inicio         DATE            NOT NULL,
    data_fim            DATE            NOT NULL,
    -- Valores
    capital_segurado    DECIMAL(15,2)   NOT NULL,
    premio_total        DECIMAL(12,2)   NOT NULL,     -- prêmio anual/total
    premio_liquido      DECIMAL(12,2)   NOT NULL,     -- sem IOF/taxas
    iof                 DECIMAL(10,2)   NOT NULL DEFAULT 0,
    franquia            DECIMAL(12,2)   NOT NULL DEFAULT 0,
    -- Parcelas
    forma_pagamento     ENUM('BOLETO','CARTAO','DEBITO','PIX') NOT NULL,
    num_parcelas        TINYINT UNSIGNED NOT NULL DEFAULT 1,
    -- Status
    status              ENUM(
                            'PROPOSTA',       -- aguardando análise
                            'ANALISE',        -- em análise de risco
                            'ATIVA',          -- vigente
                            'SUSPENSA',       -- suspensa por inadimplência
                            'CANCELADA',      -- cancelada
                            'EXPIRADA',       -- venceu sem renovação
                            'RENOVADA'        -- substituída por nova apólice
                        ) NOT NULL DEFAULT 'PROPOSTA',
    -- Renovação
    apolice_origem_id   INT UNSIGNED,   -- apólice que originou esta (renovação)
    -- Controle
    criado_em           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_apolice_cliente   FOREIGN KEY (cliente_id)  REFERENCES cliente(id),
    CONSTRAINT fk_apolice_produto   FOREIGN KEY (produto_id)  REFERENCES produto(id),
    CONSTRAINT fk_apolice_corretor  FOREIGN KEY (corretor_id) REFERENCES corretor(id),
    CONSTRAINT fk_apolice_origem    FOREIGN KEY (apolice_origem_id) REFERENCES apolice(id),
    CONSTRAINT chk_vigencia_apolice CHECK (data_fim > data_inicio),
    CONSTRAINT chk_capital_segurado CHECK (capital_segurado > 0),
    CONSTRAINT chk_premio_total     CHECK (premio_total > 0),
    CONSTRAINT chk_parcelas         CHECK (num_parcelas BETWEEN 1 AND 12),
    CONSTRAINT chk_iof              CHECK (iof >= 0),
    CONSTRAINT chk_franquia_ap      CHECK (franquia >= 0)
) ENGINE=InnoDB COMMENT='Apólices de seguro emitidas';

-- ============================================================
-- 9. COBERTURAS CONTRATADAS NA APÓLICE
-- ============================================================
CREATE TABLE IF NOT EXISTS apolice_cobertura (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    apolice_id      INT UNSIGNED    NOT NULL,
    cobertura_id    INT UNSIGNED    NOT NULL,
    limite_valor    DECIMAL(15,2)   NOT NULL,
    franquia        DECIMAL(12,2)   NOT NULL DEFAULT 0,
    premio_adicional DECIMAL(10,2)  NOT NULL DEFAULT 0,

    CONSTRAINT fk_apcob_apolice     FOREIGN KEY (apolice_id)  REFERENCES apolice(id),
    CONSTRAINT fk_apcob_cobertura   FOREIGN KEY (cobertura_id) REFERENCES cobertura(id),
    CONSTRAINT uq_apcob             UNIQUE (apolice_id, cobertura_id),
    CONSTRAINT chk_apcob_limite     CHECK (limite_valor > 0)
) ENGINE=InnoDB COMMENT='Coberturas efetivamente contratadas por apólice';

-- ============================================================
-- 10. BENEFICIÁRIOS DA APÓLICE
-- ============================================================
CREATE TABLE IF NOT EXISTS beneficiario (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    apolice_id      INT UNSIGNED    NOT NULL,
    pessoa_id       INT UNSIGNED    NOT NULL,
    grau_parentesco VARCHAR(50),
    percentual      DECIMAL(5,2)    NOT NULL,   -- % do capital segurado
    principal       TINYINT(1)      NOT NULL DEFAULT 0,

    CONSTRAINT fk_benef_apolice     FOREIGN KEY (apolice_id)  REFERENCES apolice(id),
    CONSTRAINT fk_benef_pessoa      FOREIGN KEY (pessoa_id)   REFERENCES pessoa(id),
    CONSTRAINT chk_percentual_benef CHECK (percentual > 0 AND percentual <= 100)
) ENGINE=InnoDB COMMENT='Beneficiários designados nas apólices';

-- Trigger: soma dos percentuais dos beneficiários de uma apólice não pode exceder 100%
DELIMITER $$
CREATE TRIGGER trg_beneficiario_percentual_bi
BEFORE INSERT ON beneficiario
FOR EACH ROW
BEGIN
    DECLARE total DECIMAL(6,2);
    SELECT COALESCE(SUM(percentual), 0) INTO total
    FROM beneficiario WHERE apolice_id = NEW.apolice_id;
    IF total + NEW.percentual > 100 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Soma dos percentuais dos beneficiários ultrapassa 100%.';
    END IF;
END$$
DELIMITER ;

-- ============================================================
-- 11. PARCELAS DA APÓLICE
-- ============================================================
CREATE TABLE IF NOT EXISTS parcela (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    apolice_id      INT UNSIGNED    NOT NULL,
    numero          TINYINT UNSIGNED NOT NULL,          -- 1, 2, 3...
    valor           DECIMAL(10,2)   NOT NULL,
    data_vencimento DATE            NOT NULL,
    data_pagamento  DATE,
    status          ENUM('PENDENTE','PAGA','ATRASADA','CANCELADA') NOT NULL DEFAULT 'PENDENTE',
    forma_pagamento ENUM('BOLETO','CARTAO','DEBITO','PIX'),
    nosso_numero    VARCHAR(50),                         -- referência bancária

    CONSTRAINT fk_parcela_apolice   FOREIGN KEY (apolice_id) REFERENCES apolice(id),
    CONSTRAINT uq_parcela           UNIQUE (apolice_id, numero),
    CONSTRAINT chk_valor_parcela    CHECK (valor > 0)
) ENGINE=InnoDB COMMENT='Parcelas do prêmio por apólice';

-- Trigger: suspender apólice ao detectar parcela atrasada > 30 dias
DELIMITER $$
CREATE TRIGGER trg_parcela_atraso_bu
BEFORE UPDATE ON parcela
FOR EACH ROW
BEGIN
    IF NEW.status = 'ATRASADA' THEN
        UPDATE apolice SET status = 'SUSPENSA'
        WHERE id = NEW.apolice_id AND status = 'ATIVA';
    END IF;
END$$
DELIMITER ;

-- ============================================================
-- 12. SINISTROS
-- ============================================================
CREATE TABLE IF NOT EXISTS sinistro (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero              VARCHAR(30)     NOT NULL UNIQUE,
    apolice_id          INT UNSIGNED    NOT NULL,
    cobertura_id        INT UNSIGNED    NOT NULL,
    -- Evento
    data_ocorrencia     DATETIME        NOT NULL,
    data_comunicacao    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descricao           TEXT            NOT NULL,
    local_ocorrencia    VARCHAR(300),
    -- Valores
    valor_reclamado     DECIMAL(15,2)   NOT NULL,
    valor_pericia       DECIMAL(15,2),
    valor_aprovado      DECIMAL(15,2),
    franquia_aplicada   DECIMAL(12,2)   NOT NULL DEFAULT 0,
    valor_indenizacao   DECIMAL(15,2)   GENERATED ALWAYS AS (
                            GREATEST(0, COALESCE(valor_aprovado,0) - franquia_aplicada)
                        ) STORED,
    -- Status do fluxo
    status              ENUM(
                            'ABERTO',
                            'EM_PERICIA',
                            'AGUARDANDO_DOCUMENTOS',
                            'EM_ANALISE',
                            'APROVADO',
                            'PARCIALMENTE_APROVADO',
                            'NEGADO',
                            'PAGO',
                            'CANCELADO',
                            'RECURSO'
                        ) NOT NULL DEFAULT 'ABERTO',
    -- Terceiros envolvidos
    terceiro_envolvido  TINYINT(1)      NOT NULL DEFAULT 0,
    -- Controle
    responsavel_id      INT UNSIGNED,   -- analista interno (pessoa)
    criado_em           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_sinistro_apolice   FOREIGN KEY (apolice_id)   REFERENCES apolice(id),
    CONSTRAINT fk_sinistro_cobertura FOREIGN KEY (cobertura_id) REFERENCES cobertura(id),
    CONSTRAINT fk_sinistro_resp      FOREIGN KEY (responsavel_id) REFERENCES pessoa(id),
    -- Data de ocorrência não pode ser futura
    CONSTRAINT chk_data_ocorrencia  CHECK (data_ocorrencia <= NOW()),
    -- Comunicação não pode ser anterior à ocorrência
    CONSTRAINT chk_data_comunicacao CHECK (data_comunicacao >= data_ocorrencia),
    CONSTRAINT chk_valor_reclamado  CHECK (valor_reclamado > 0),
    CONSTRAINT chk_valor_aprovado   CHECK (valor_aprovado IS NULL OR valor_aprovado >= 0)
) ENGINE=InnoDB COMMENT='Registro e acompanhamento de sinistros';

-- ============================================================
-- 13. DOCUMENTOS DO SINISTRO
-- ============================================================
CREATE TABLE IF NOT EXISTS sinistro_documento (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sinistro_id     INT UNSIGNED    NOT NULL,
    tipo            ENUM(
                        'BO',               -- Boletim de Ocorrência
                        'NOTA_FISCAL',
                        'LAUDO_MEDICO',
                        'FOTO',
                        'VIDEO',
                        'CONTRATO',
                        'DECLARACAO',
                        'OUTROS'
                    ) NOT NULL,
    nome_arquivo    VARCHAR(255)    NOT NULL,
    caminho         VARCHAR(500)    NOT NULL,
    tamanho_bytes   INT UNSIGNED,
    enviado_em      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    enviado_por     INT UNSIGNED    NOT NULL,   -- pessoa_id

    CONSTRAINT fk_sindoc_sinistro   FOREIGN KEY (sinistro_id) REFERENCES sinistro(id),
    CONSTRAINT fk_sindoc_enviado    FOREIGN KEY (enviado_por) REFERENCES pessoa(id)
) ENGINE=InnoDB COMMENT='Documentos anexados ao sinistro';

-- ============================================================
-- 14. HISTÓRICO / ANDAMENTOS DO SINISTRO
-- ============================================================
CREATE TABLE IF NOT EXISTS sinistro_historico (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sinistro_id     INT UNSIGNED    NOT NULL,
    status_anterior VARCHAR(50),
    status_novo     VARCHAR(50)     NOT NULL,
    observacao      TEXT,
    usuario_id      INT UNSIGNED    NOT NULL,   -- pessoa_id do operador
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sinhist_sinistro  FOREIGN KEY (sinistro_id) REFERENCES sinistro(id),
    CONSTRAINT fk_sinhist_usuario   FOREIGN KEY (usuario_id)  REFERENCES pessoa(id)
) ENGINE=InnoDB COMMENT='Trilha de auditoria de status do sinistro';

-- Trigger: gravar histórico automaticamente ao alterar status do sinistro
DELIMITER $$
CREATE TRIGGER trg_sinistro_historico_au
AFTER UPDATE ON sinistro
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO sinistro_historico
            (sinistro_id, status_anterior, status_novo, observacao, usuario_id)
        VALUES
            (NEW.id, OLD.status, NEW.status, 'Atualização automática via trigger', COALESCE(NEW.responsavel_id, 1));
    END IF;
END$$
DELIMITER ;

-- ============================================================
-- 15. PERITOS
-- ============================================================
CREATE TABLE IF NOT EXISTS perito (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id       INT UNSIGNED    NOT NULL UNIQUE,
    crea_crm        VARCHAR(30),           -- registro profissional
    especialidade   VARCHAR(100),
    ativo           TINYINT(1)      NOT NULL DEFAULT 1,
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_perito_pessoa     FOREIGN KEY (pessoa_id) REFERENCES pessoa(id)
) ENGINE=InnoDB COMMENT='Peritos para avaliação de sinistros';

-- ============================================================
-- 16. PERÍCIAS
-- ============================================================
CREATE TABLE IF NOT EXISTS pericia (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sinistro_id     INT UNSIGNED    NOT NULL,
    perito_id       INT UNSIGNED    NOT NULL,
    data_agendada   DATETIME        NOT NULL,
    data_realizada  DATETIME,
    local           VARCHAR(300),
    laudo           TEXT,
    valor_estimado  DECIMAL(15,2),
    resultado       ENUM('CONFIRMADO','PARCIAL','NEGADO','PENDENTE') NOT NULL DEFAULT 'PENDENTE',
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pericia_sinistro  FOREIGN KEY (sinistro_id) REFERENCES sinistro(id),
    CONSTRAINT fk_pericia_perito    FOREIGN KEY (perito_id)   REFERENCES perito(id),
    CONSTRAINT chk_data_realizada   CHECK (data_realizada IS NULL OR data_realizada >= data_agendada)
) ENGINE=InnoDB COMMENT='Laudos periciais vinculados a sinistros';

-- ============================================================
-- 17. INDENIZAÇÕES / PAGAMENTOS DE SINISTRO
-- ============================================================
CREATE TABLE IF NOT EXISTS indenizacao (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sinistro_id     INT UNSIGNED    NOT NULL UNIQUE,   -- 1 indenização por sinistro
    valor_bruto     DECIMAL(15,2)   NOT NULL,
    imposto_retido  DECIMAL(10,2)   NOT NULL DEFAULT 0,
    valor_liquido   DECIMAL(15,2)   NOT NULL,
    forma_pagamento ENUM('TED','PIX','BOLETO','CHEQUE') NOT NULL,
    banco           VARCHAR(100),
    agencia         VARCHAR(10),
    conta           VARCHAR(20),
    chave_pix       VARCHAR(150),
    data_aprovacao  DATE            NOT NULL,
    data_pagamento  DATE,
    status          ENUM('AGUARDANDO','PROCESSANDO','PAGO','ESTORNADO') NOT NULL DEFAULT 'AGUARDANDO',
    comprovante     VARCHAR(500),   -- path do arquivo

    CONSTRAINT fk_indeniz_sinistro  FOREIGN KEY (sinistro_id) REFERENCES sinistro(id),
    CONSTRAINT chk_valor_bruto      CHECK (valor_bruto > 0),
    CONSTRAINT chk_valor_liquido    CHECK (valor_liquido >= 0),
    CONSTRAINT chk_imposto          CHECK (imposto_retido >= 0),
    CONSTRAINT chk_data_pgto        CHECK (data_pagamento IS NULL OR data_pagamento >= data_aprovacao)
) ENGINE=InnoDB COMMENT='Indenizações pagas nos sinistros';

-- ============================================================
-- 18. COMISSÕES DOS CORRETORES
-- ============================================================
CREATE TABLE IF NOT EXISTS comissao (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    corretor_id     INT UNSIGNED    NOT NULL,
    apolice_id      INT UNSIGNED    NOT NULL,
    parcela_id      INT UNSIGNED,
    valor_base      DECIMAL(12,2)   NOT NULL,
    percentual      DECIMAL(5,2)    NOT NULL,
    valor_comissao  DECIMAL(10,2)   NOT NULL,
    competencia     DATE            NOT NULL,    -- mês/ano de referência
    status          ENUM('PENDENTE','PAGA','ESTORNADA') NOT NULL DEFAULT 'PENDENTE',
    paga_em         DATE,

    CONSTRAINT fk_comiss_corretor   FOREIGN KEY (corretor_id) REFERENCES corretor(id),
    CONSTRAINT fk_comiss_apolice    FOREIGN KEY (apolice_id)  REFERENCES apolice(id),
    CONSTRAINT fk_comiss_parcela    FOREIGN KEY (parcela_id)  REFERENCES parcela(id),
    CONSTRAINT chk_comiss_pct       CHECK (percentual BETWEEN 0 AND 30),
    CONSTRAINT chk_comiss_valor     CHECK (valor_comissao >= 0)
) ENGINE=InnoDB COMMENT='Comissões devidas aos corretores';

-- ============================================================
-- 19. RESSEGUROS
-- ============================================================
CREATE TABLE IF NOT EXISTS ressegurador (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(150)    NOT NULL,
    cnpj            CHAR(14)        NOT NULL UNIQUE,
    susep           VARCHAR(20)     NOT NULL UNIQUE,
    ativo           TINYINT(1)      NOT NULL DEFAULT 1
) ENGINE=InnoDB COMMENT='Resseguradoras parceiras';

CREATE TABLE IF NOT EXISTS resseguro (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    apolice_id      INT UNSIGNED    NOT NULL,
    ressegurador_id INT UNSIGNED    NOT NULL,
    percentual_cede DECIMAL(5,2)    NOT NULL,   -- % do risco cedido
    premio_cedido   DECIMAL(12,2)   NOT NULL,
    vigencia_inicio DATE            NOT NULL,
    vigencia_fim    DATE            NOT NULL,
    ativo           TINYINT(1)      NOT NULL DEFAULT 1,

    CONSTRAINT fk_resseg_apolice    FOREIGN KEY (apolice_id)      REFERENCES apolice(id),
    CONSTRAINT fk_resseg_ress       FOREIGN KEY (ressegurador_id) REFERENCES ressegurador(id),
    CONSTRAINT chk_cede_pct         CHECK (percentual_cede BETWEEN 0 AND 100),
    CONSTRAINT chk_resseg_vig       CHECK (vigencia_fim > vigencia_inicio)
) ENGINE=InnoDB COMMENT='Resseguro cedido por apólice';

-- ============================================================
-- 20. RECLAMAÇÕES / OUVIDORIA
-- ============================================================
CREATE TABLE IF NOT EXISTS reclamacao (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero_protocolo VARCHAR(20)    NOT NULL UNIQUE,
    cliente_id      INT UNSIGNED    NOT NULL,
    apolice_id      INT UNSIGNED,
    sinistro_id     INT UNSIGNED,
    canal           ENUM('TELEFONE','EMAIL','CHAT','PRESENCIAL','SUSEP') NOT NULL,
    assunto         VARCHAR(200)    NOT NULL,
    descricao       TEXT            NOT NULL,
    status          ENUM('ABERTA','EM_ANALISE','RESOLVIDA','IMPROCEDENTE','ESCALADA') NOT NULL DEFAULT 'ABERTA',
    prazo_resposta  DATE,                       -- SLA de resposta
    data_resolucao  DATE,
    resposta        TEXT,
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_reclam_cliente    FOREIGN KEY (cliente_id)  REFERENCES cliente(id),
    CONSTRAINT fk_reclam_apolice    FOREIGN KEY (apolice_id)  REFERENCES apolice(id),
    CONSTRAINT fk_reclam_sinistro   FOREIGN KEY (sinistro_id) REFERENCES sinistro(id)
) ENGINE=InnoDB COMMENT='Reclamações e ouvidoria';

-- ============================================================
-- 21. AUDITORIA GERAL (log de alterações críticas)
-- ============================================================
CREATE TABLE IF NOT EXISTS auditoria (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tabela          VARCHAR(80)     NOT NULL,
    registro_id     INT UNSIGNED    NOT NULL,
    operacao        ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    dados_antes     JSON,
    dados_depois    JSON,
    usuario         VARCHAR(100),
    ip_origem       VARCHAR(45),
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_aud_tabela    (tabela),
    INDEX idx_aud_registro  (tabela, registro_id),
    INDEX idx_aud_data      (criado_em)
) ENGINE=InnoDB COMMENT='Log de auditoria de todas as operações críticas';

-- ============================================================
-- 22. USUÁRIOS DO SISTEMA (operadores internos)
-- ============================================================
CREATE TABLE IF NOT EXISTS usuario (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id       INT UNSIGNED    NOT NULL UNIQUE,
    login           VARCHAR(60)     NOT NULL UNIQUE,
    senha_hash      CHAR(60)        NOT NULL,   -- bcrypt
    perfil          ENUM('ADMIN','ANALISTA','CORRETOR','CAIXA','AUDITOR','OUVIDORIA') NOT NULL,
    ativo           TINYINT(1)      NOT NULL DEFAULT 1,
    ultimo_acesso   DATETIME,
    tentativas_falha TINYINT UNSIGNED NOT NULL DEFAULT 0,
    bloqueado       TINYINT(1)      NOT NULL DEFAULT 0,
    criado_em       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_usuario_pessoa    FOREIGN KEY (pessoa_id) REFERENCES pessoa(id),
    CONSTRAINT chk_tentativas       CHECK (tentativas_falha <= 5)
) ENGINE=InnoDB COMMENT='Usuários operadores do sistema';

-- ============================================================
-- 23. ANÁLISE DE RISCO (subscrição)
-- ============================================================
CREATE TABLE IF NOT EXISTS analise_risco (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    apolice_id      INT UNSIGNED    NOT NULL UNIQUE,
    analista_id     INT UNSIGNED    NOT NULL,   -- usuario_id
    data_analise    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    score_risco     TINYINT UNSIGNED NOT NULL,  -- 0-100
    fatores         JSON,                       -- JSON com fatores de risco
    parecer         ENUM('APROVADO','APROVADO_COM_RESTRICOES','RECUSADO') NOT NULL,
    observacoes     TEXT,
    carencia_dias   SMALLINT UNSIGNED NOT NULL DEFAULT 0,  -- carência em dias

    CONSTRAINT fk_analise_apolice   FOREIGN KEY (apolice_id)  REFERENCES apolice(id),
    CONSTRAINT fk_analise_analista  FOREIGN KEY (analista_id) REFERENCES usuario(id),
    CONSTRAINT chk_score_analise    CHECK (score_risco BETWEEN 0 AND 100),
    CONSTRAINT chk_carencia         CHECK (carencia_dias <= 730)
) ENGINE=InnoDB COMMENT='Análise de subscrição de risco por apólice';

-- ============================================================
-- 24. TABELAS DE PREÇO / TARIFAÇÃO
-- ============================================================
CREATE TABLE IF NOT EXISTS tabela_preco (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    produto_id      INT UNSIGNED    NOT NULL,
    descricao       VARCHAR(200)    NOT NULL,
    vigencia_inicio DATE            NOT NULL,
    vigencia_fim    DATE,
    ativa           TINYINT(1)      NOT NULL DEFAULT 1,

    CONSTRAINT fk_tabpreco_produto  FOREIGN KEY (produto_id) REFERENCES produto(id),
    CONSTRAINT chk_tabpreco_vig     CHECK (vigencia_fim IS NULL OR vigencia_fim >= vigencia_inicio)
) ENGINE=InnoDB COMMENT='Versões de tabelas de preço por produto';

CREATE TABLE IF NOT EXISTS tabela_preco_faixa (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tabela_preco_id INT UNSIGNED    NOT NULL,
    faixa_min       DECIMAL(15,2)   NOT NULL,   -- capital segurado mínimo
    faixa_max       DECIMAL(15,2)   NOT NULL,   -- capital segurado máximo
    taxa_pct        DECIMAL(6,4)    NOT NULL,   -- taxa do prêmio em %
    agravo_pct      DECIMAL(5,2)    NOT NULL DEFAULT 0,   -- agravo por risco

    CONSTRAINT fk_faixa_tabela      FOREIGN KEY (tabela_preco_id) REFERENCES tabela_preco(id),
    CONSTRAINT chk_faixa_range      CHECK (faixa_max > faixa_min),
    CONSTRAINT chk_taxa             CHECK (taxa_pct > 0)
) ENGINE=InnoDB COMMENT='Faixas tarifárias das tabelas de preço';

-- ============================================================
-- VIEWS ÚTEIS
-- ============================================================

-- Resumo das apólices ativas com informações do cliente
CREATE OR REPLACE VIEW vw_apolices_ativas AS
SELECT
    a.id,
    a.numero,
    a.status,
    a.data_inicio,
    a.data_fim,
    a.capital_segurado,
    a.premio_total,
    p.nome                                          AS cliente_nome,
    p.cpf                                           AS cliente_cpf,
    pr.nome                                         AS produto_nome,
    r.nome                                          AS ramo,
    pc.nome                                         AS corretor_nome,
    DATEDIFF(a.data_fim, CURDATE())                 AS dias_para_vencer
FROM apolice a
JOIN cliente  c  ON c.id = a.cliente_id
JOIN pessoa   p  ON p.id = c.pessoa_id
JOIN produto  pr ON pr.id = a.produto_id
JOIN ramo     r  ON r.id = pr.ramo_id
LEFT JOIN corretor co ON co.id = a.corretor_id
LEFT JOIN pessoa   pc ON pc.id = co.pessoa_id
WHERE a.status = 'ATIVA';

-- Sinistros em aberto com valor potencial de indenização
CREATE OR REPLACE VIEW vw_sinistros_abertos AS
SELECT
    s.id,
    s.numero,
    s.status,
    s.data_ocorrencia,
    s.valor_reclamado,
    s.valor_aprovado,
    s.valor_indenizacao,
    a.numero                                        AS numero_apolice,
    p.nome                                          AS cliente_nome,
    co.nome                                         AS cobertura_nome,
    DATEDIFF(NOW(), s.data_ocorrencia)              AS dias_aberto
FROM sinistro s
JOIN apolice  a  ON a.id = s.apolice_id
JOIN cliente  cl ON cl.id = a.cliente_id
JOIN pessoa   p  ON p.id = cl.pessoa_id
JOIN cobertura co ON co.id = s.cobertura_id
WHERE s.status NOT IN ('PAGO','CANCELADO','NEGADO');

-- Parcelas vencidas (inadimplência)
CREATE OR REPLACE VIEW vw_parcelas_vencidas AS
SELECT
    pa.id,
    pa.apolice_id,
    a.numero                                        AS numero_apolice,
    p.nome                                          AS cliente_nome,
    pa.numero                                       AS num_parcela,
    pa.valor,
    pa.data_vencimento,
    DATEDIFF(CURDATE(), pa.data_vencimento)         AS dias_atraso
FROM parcela  pa
JOIN apolice  a  ON a.id = pa.apolice_id
JOIN cliente  cl ON cl.id = a.cliente_id
JOIN pessoa   p  ON p.id = cl.pessoa_id
WHERE pa.status = 'PENDENTE'
  AND pa.data_vencimento < CURDATE()
ORDER BY dias_atraso DESC;

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

-- SP: Emitir apólice (muda status de PROPOSTA para ATIVA após aprovação)
DELIMITER $$
CREATE PROCEDURE sp_emitir_apolice(IN p_apolice_id INT UNSIGNED, IN p_usuario_id INT UNSIGNED)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_parecer VARCHAR(30);

    SELECT status INTO v_status FROM apolice WHERE id = p_apolice_id;

    IF v_status <> 'ANALISE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Apólice não está em análise.';
    END IF;

    SELECT parecer INTO v_parecer FROM analise_risco WHERE apolice_id = p_apolice_id;

    IF v_parecer NOT IN ('APROVADO','APROVADO_COM_RESTRICOES') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Análise de risco não aprovada.';
    END IF;

    UPDATE apolice SET status = 'ATIVA' WHERE id = p_apolice_id;

    INSERT INTO auditoria (tabela, registro_id, operacao, dados_depois, usuario)
    VALUES ('apolice', p_apolice_id, 'UPDATE',
            JSON_OBJECT('status','ATIVA','emitida_por', p_usuario_id),
            (SELECT login FROM usuario WHERE id = p_usuario_id));
END$$
DELIMITER ;

-- SP: Registrar sinistro
DELIMITER $$
CREATE PROCEDURE sp_registrar_sinistro(
    IN p_apolice_id      INT UNSIGNED,
    IN p_cobertura_id    INT UNSIGNED,
    IN p_data_ocorrencia DATETIME,
    IN p_descricao       TEXT,
    IN p_valor_reclamado DECIMAL(15,2),
    OUT p_sinistro_id    INT UNSIGNED
)
BEGIN
    DECLARE v_status_apolice VARCHAR(20);
    DECLARE v_numero_sinistro VARCHAR(30);

    -- Verifica se a apólice está ativa
    SELECT status INTO v_status_apolice FROM apolice WHERE id = p_apolice_id;
    IF v_status_apolice <> 'ATIVA' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Apólice não está ativa.';
    END IF;

    -- Verifica se a cobertura pertence ao produto da apólice
    IF NOT EXISTS (
        SELECT 1 FROM apolice_cobertura
        WHERE apolice_id = p_apolice_id AND cobertura_id = p_cobertura_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cobertura não contratada nesta apólice.';
    END IF;

    -- Gera número sequencial
    SET v_numero_sinistro = CONCAT('SIN-', DATE_FORMAT(NOW(), '%Y%m'), '-',
                                   LPAD(FLOOR(RAND()*999999), 6, '0'));

    INSERT INTO sinistro
        (numero, apolice_id, cobertura_id, data_ocorrencia, descricao, valor_reclamado)
    VALUES
        (v_numero_sinistro, p_apolice_id, p_cobertura_id, p_data_ocorrencia, p_descricao, p_valor_reclamado);

    SET p_sinistro_id = LAST_INSERT_ID();
END$$
DELIMITER ;

-- SP: Calcular prêmio com base na tabela de preços
DELIMITER $$
CREATE PROCEDURE sp_calcular_premio(
    IN  p_produto_id      INT UNSIGNED,
    IN  p_capital_segurado DECIMAL(15,2),
    OUT p_premio          DECIMAL(12,2)
)
BEGIN
    DECLARE v_taxa DECIMAL(6,4);
    SELECT taxa_pct INTO v_taxa
    FROM tabela_preco_faixa f
    JOIN tabela_preco t ON t.id = f.tabela_preco_id
    WHERE t.produto_id = p_produto_id
      AND t.ativa = 1
      AND (t.vigencia_fim IS NULL OR t.vigencia_fim >= CURDATE())
      AND p_capital_segurado BETWEEN f.faixa_min AND f.faixa_max
    LIMIT 1;

    IF v_taxa IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nenhuma faixa tarifária encontrada para o capital informado.';
    END IF;

    SET p_premio = ROUND(p_capital_segurado * v_taxa / 100, 2);
END$$
DELIMITER ;

-- ============================================================
-- ÍNDICES DE DESEMPENHO
-- ============================================================
CREATE INDEX idx_apolice_cliente     ON apolice  (cliente_id);
CREATE INDEX idx_apolice_status      ON apolice  (status);
CREATE INDEX idx_apolice_vigencia    ON apolice  (data_inicio, data_fim);
CREATE INDEX idx_parcela_vencimento  ON parcela  (data_vencimento, status);
CREATE INDEX idx_sinistro_status     ON sinistro (status);
CREATE INDEX idx_sinistro_apolice    ON sinistro (apolice_id);
CREATE INDEX idx_pessoa_cpf          ON pessoa   (cpf);
CREATE INDEX idx_pessoa_cnpj         ON pessoa   (cnpj);
CREATE INDEX idx_comissao_corretor   ON comissao (corretor_id, competencia);

-- ============================================================
-- DADOS INICIAIS (seed)
-- ============================================================

INSERT INTO ramo (codigo, nome, descricao) VALUES
('AUTO',     'Automóvel',        'Seguros para veículos automotores'),
('VIDA',     'Vida',             'Seguros de vida individual e em grupo'),
('SAUDE',    'Saúde',            'Planos e seguros de saúde'),
('INCENDIO', 'Incêndio',         'Seguros contra incêndio e danos ao imóvel'),
('VIAGEM',   'Viagem',           'Seguros de viagem nacional e internacional'),
('RC',       'Resp. Civil',      'Responsabilidade civil geral'),
('RURAL',    'Rural',            'Seguros para atividades rurais e agropecuárias');

SET FOREIGN_KEY_CHECKS = 1;

-- FIM DO SCRIPT
