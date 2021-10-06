CREATE TABLE pi_app_react.app.usuario (
	id_usuario INT PRIMARY KEY IDENTITY(1,1),
	username VARCHAR(64) UNIQUE NOT NULL,
	[password] VARCHAR(64) NOT NULL
);

CREATE TABLE pi_app_react.app.pessoa (
	id_pessoa INT PRIMARY KEY IDENTITY(1,1),
	id_usuario INT,
	primeiro_nome VARCHAR(64) NOT NULL,
	ultimo_nome VARCHAR(64) NOT NULL,
	cpf VARCHAR(64),
	dta_nascimento DATE,
	endereco VARCHAR(128),
	email VARCHAR(128),
	telefone VARCHAR(32)

);

ALTER TABLE pi_app_react.app.pessoa 
ADD CONSTRAINT pessoa_id_usuario_fk 
FOREIGN KEY (id_usuario) REFERENCES app.usuario(id_usuario);


CREATE TABLE pi_app_react.app.empresa (
	id_empresa INT PRIMARY KEY IDENTITY(1,1),
	id_usuario INT,
	sigla VARCHAR(16),
	nome VARCHAR(64) NOT NULL,
	des_empresa VARCHAR(64) NOT NULL,
	cnpj VARCHAR(64),
	tipo_empresa VARCHAR(24),
	endereco VARCHAR(128),
	email VARCHAR(128),
	telefone VARCHAR(32)

);


ALTER TABLE pi_app_react.app.empresa 
ADD CONSTRAINT empresa_id_usuario_fk 
FOREIGN KEY (id_usuario) REFERENCES app.usuario(id_usuario);


CREATE TABLE pi_app_react.app.mensagem (
	id_mensagem INT PRIMARY KEY IDENTITY(1,1),
	id_pessoa INT,
	id_empresa INT,
	msn VARCHAR(256),
	sentido_msn TINYINT
);

ALTER TABLE pi_app_react.app.mensagem 
ADD CONSTRAINT mensagem_id_pessoa_fk 
FOREIGN KEY (id_pessoa) REFERENCES app.pessoa(id_pessoa);

ALTER TABLE pi_app_react.app.mensagem 
ADD CONSTRAINT mensagem_id_empresa_fk 
FOREIGN KEY (id_empresa) REFERENCES app.empresa(id_empresa);

CREATE TABLE pi_app_react.app.categoria (
	id_categoria INT PRIMARY KEY IDENTITY(1,1),
	nome VARCHAR(32) NOT NULL UNIQUE,
	des_categoria VARCHAR(512)
);

CREATE TABLE pi_app_react.app.pagamento (
	id_pagamento INT PRIMARY KEY IDENTITY(1,1),
	forma_pagamento VARCHAR(32),
	valor_bruto FLOAT,
	valor_desconto FLOAT
);

CREATE TABLE pi_app_react.app.servico (
	id_servico INT PRIMARY KEY IDENTITY(1,1),
	nome_servico VARCHAR(256) NOT NULL,
	des_servico VARCHAR(512) NOT NULL,
	dta_inicio DATETIME,
	dta_fim DATETIME,
	status VARCHAR(32) DEFAULT 'catalogo', -- considerando 3 status: catalogo (servicos de amostra), contratado e pago
	id_pessoa INT,
	id_empresa INT NOT NULL,
	id_categoria INT NOT NULL,
	id_pagamento INT
);

ALTER TABLE pi_app_react.app.servico 
ADD CONSTRAINT servico_id_pessoa_fk 
FOREIGN KEY (id_pessoa) REFERENCES app.pessoa(id_pessoa);

ALTER TABLE pi_app_react.app.servico 
ADD CONSTRAINT servico_id_empresa_fk 
FOREIGN KEY (id_empresa) REFERENCES app.empresa(id_empresa);

ALTER TABLE pi_app_react.app.servico 
ADD CONSTRAINT servico_id_categoria_fk 
FOREIGN KEY (id_categoria) REFERENCES app.categoria(id_categoria);

ALTER TABLE pi_app_react.app.servico 
ADD CONSTRAINT servico_id_pagamento_fk 
FOREIGN KEY (id_pagamento) REFERENCES app.pagamento(id_pagamento);
GO
