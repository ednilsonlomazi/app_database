
CREATE PROCEDURE app.insere_servico 
(
	@nome_servico VARCHAR(256),
	@des_servico VARCHAR(512),
	@categoria VARCHAR(256),
	@nome_empresa VARCHAR(256)
) 
AS BEGIN TRY
	BEGIN TRANSACTION

		INSERT INTO pi_app_react.app.servico 
		(nome_servico, des_servico, id_categoria, id_empresa)
		VALUES (
			@nome_servico,
			@des_servico,
			(
				SELECT id_categoria 
				FROM pi_app_react.app.categoria c 
				WHERE c.nome = @categoria 
			),
			(
				SELECT id_empresa 
				FROM pi_app_react.app.empresa e 
				WHERE e.nome = @nome_empresa
			)
			
		)
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH
GO

CREATE PROCEDURE app.contratar_servico 
(
	@username VARCHAR(64),
	@id_servico INT,
	@dta_inicio DATETIME,
	@dta_fim DATETIME
)
AS BEGIN TRY
	BEGIN TRANSACTION
		DECLARE @id_pessoa INT = (
			SELECT p.id_pessoa 
			FROM pi_app_react.app.pessoa p 
				INNER JOIN pi_app_react.app.usuario u 
					ON u.id_usuario = p.id_usuario 
			WHERE u.username = @username
		)
		
		DECLARE @id_empresa INT = (
			SELECT e.id_empresa
			FROM pi_app_react.app.empresa e
				INNER JOIN pi_app_react.app.servico s
					ON s.id_empresa = e.id_empresa
			WHERE s.id_servico = @id_servico
		)
		
		IF OBJECT_ID('tempdb.dbo.#tmp_agenda') IS NOT NULL
		BEGIN
			DROP TABLE #tmp_agenda
		END

		SELECT s.dta_inicio, 
			   s.dta_fim
		INTO #tmp_agenda
		FROM pi_app_react.app.servico s
		WHERE 1 = 1 
			AND s.id_empresa = @id_empresa
			AND s.status = 'contratado'
		ORDER BY s.dta_inicio

		DECLARE @agenda_livre INT;
		
		IF EXISTS (
			SELECT TOP 1 *
			FROM #tmp_agenda
		)
		BEGIN
			DECLARE @min_dta_inicio DATETIME = (SELECT MIN(ta.dta_inicio) FROM #tmp_agenda ta)
			IF(@dta_inicio < @min_dta_inicio AND @dta_fim <= @min_dta_inicio)
			BEGIN
				SET @agenda_livre = 1;
			END ELSE
			BEGIN
				SET @agenda_livre = 0;
			END
	
			-- INICIO LOOP VERIFICA AGENDA  -------------------------------------------------
			WHILE EXISTS (
				SELECT TOP 1 *
				FROM #tmp_agenda
			) AND @agenda_livre = 0
			BEGIN

				IF OBJECT_ID('tempdb.dbo.#tmp_sub_agenda') IS NOT NULL
				BEGIN
					DROP TABLE #tmp_sub_agenda
				END
				
				SELECT TOP 2 ta.dta_inicio, 
							 ta.dta_fim 
				INTO #tmp_sub_agenda
				FROM #tmp_agenda ta

				DECLARE @dta_inicio_agenda_1 DATETIME,
						@dta_inicio_agenda_2 DATETIME,
						@dta_fim_agenda_1 DATETIME,
						@dta_fim_agenda_2 DATETIME
			 

				IF(SELECT COUNT(*) FROM #tmp_sub_agenda) = 2
				BEGIN
				
					SELECT TOP 1 @dta_inicio_agenda_1 = tsa.dta_inicio, 
								 @dta_fim_agenda_1 = tsa.dta_fim
					FROM #tmp_sub_agenda tsa
					ORDER BY tsa.dta_inicio ASC

					SELECT TOP 1 @dta_inicio_agenda_2 = tsa.dta_inicio, 
								 @dta_fim_agenda_2 = tsa.dta_fim
					FROM #tmp_sub_agenda tsa
					ORDER BY tsa.dta_inicio DESC


					IF(@dta_inicio >= @dta_fim_agenda_1 AND @dta_fim <= @dta_inicio_agenda_2 )
					BEGIN
						SET @agenda_livre = 1
						DELETE #tmp_agenda FROM #tmp_agenda
					END 
				END ELSE
				BEGIN
				
					SELECT TOP 1 @dta_fim_agenda_1 = tsa.dta_fim 
					FROM #tmp_sub_agenda tsa
				

					IF(@dta_inicio >= @dta_fim_agenda_1)
					BEGIN
						SET @agenda_livre = 1
						DELETE #tmp_agenda FROM #tmp_agenda
					END
				END

				DELETE FROM #tmp_agenda
				WHERE #tmp_agenda.dta_inicio = (SELECT MIN(ta.dta_inicio) FROM #tmp_agenda ta)
			END
		END ELSE
		BEGIN
			SET @agenda_livre = 1
		END

		SELECT @agenda_livre
		IF NOT EXISTS (
			SELECT s.id_servico 
			FROM pi_app_react.app.servico s 
			WHERE 1 = 1
				AND s.id_servico = @id_servico
				AND s.id_pessoa = @id_pessoa
		) AND @agenda_livre = 1
		BEGIN
			
			INSERT INTO pi_app_react.app.servico
			SELECT s.nome_servico, 
				   s.des_servico, 
				   s.dta_inicio, 
				   s.dta_fim, 
				   s.status, 
				   s.id_pessoa, 
				   s.id_empresa, 
				   s.id_categoria, 
				   s.id_pagamento 
			FROM pi_app_react.app.servico s
			WHERE s.id_servico = @id_servico
			
			UPDATE pi_app_react.app.servico
			SET id_pessoa = @id_pessoa,
				status = 'contratado',
				dta_inicio = @dta_inicio,
				dta_fim = @dta_fim
			WHERE pi_app_react.app.servico.id_servico = @id_servico
		END

		IF(@agenda_livre = 0)
		BEGIN
			RAISERROR('Horário Indisponível', 16, 1)
		END


	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);	
END CATCH
GO


CREATE PROCEDURE app.insere_pagamento 
(
	@id_servico INT,
	@forma_pagamento VARCHAR(32),
	@valor_bruto FLOAT,
	@valor_desconto FLOAT
)
AS BEGIN TRY
	BEGIN TRANSACTION
		IF (
			SELECT s.id_pessoa 
			FROM pi_app_react.app.servico s 
			WHERE s.id_servico = @id_servico
		) IS NOT NULL
		BEGIN
			INSERT INTO pi_app_react.app.pagamento VALUES (
				@forma_pagamento,
				@valor_bruto,
				@valor_desconto
			)
		
			UPDATE pi_app_react.app.servico
			SET pi_app_react.app.servico.status = 'pago',
				pi_app_react.app.servico.id_pagamento = (SELECT MAX(p.id_pagamento) FROM pi_app_react.app.pagamento p)
			WHERE pi_app_react.app.servico.id_servico = @id_servico	
		END
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH
GO


CREATE PROCEDURE app.insere_categoria
(
	@nome VARCHAR(64),
	@des_categoria VARCHAR(256)
)
AS BEGIN TRY
	INSERT INTO pi_app_react.app.categoria VALUES
	(@nome, @des_categoria)
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH
GO


CREATE PROCEDURE app.insere_usuario
(
	@username VARCHAR(64),
	@password VARCHAR(64),
	@id_usuario INT OUTPUT
) 
AS BEGIN
	INSERT INTO pi_app_react.app.usuario VALUES
	(@username, @password);

	SELECT @id_usuario = MAX(pi_app_react.app.usuario.id_usuario) 
	FROM pi_app_react.app.usuario
	
	RETURN
END
GO


CREATE PROCEDURE app.insere_mensagem 
(
	@username_pessoa VARCHAR(64),
	@username_empresa VARCHAR(64),
	@msn VARCHAR(256),
	@sentido_msn TINYINT	
)
AS BEGIN TRY
	BEGIN TRANSACTION
		INSERT INTO pi_app_react.app.mensagem VALUES(
			(
				SELECT p.id_pessoa 
				FROM pi_app_react.app.pessoa p
					INNER JOIN pi_app_react.app.usuario u
						ON u.id_usuario = p.id_usuario
				WHERE u.username = @username_pessoa
				
			),
			(
				SELECT e.id_empresa 
				FROM pi_app_react.app.empresa e
					INNER JOIN pi_app_react.app.usuario u
						ON u.id_usuario = e.id_usuario
				WHERE u.username = @username_empresa

			),
			@msn,
			@sentido_msn
		)
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH
GO


CREATE PROCEDURE app.insere_pessoa
(
	@username VARCHAR(64),
	@password VARCHAR(64),
	@primeiro_nome VARCHAR(64),
	@ultimo_nome VARCHAR(64),
	@cpf VARCHAR(64),
	@dta_nascimento DATE,
	@endereco VARCHAR(128),
	@email VARCHAR(128),
	@telefone VARCHAR(32),
	@id_pessoa INT = NULL OUTPUT
) 
AS BEGIN TRY
	BEGIN TRANSACTION
		DECLARE @id_novo_usuario INT;
		EXEC pi_app_react.app.insere_usuario @username, @password, @id_novo_usuario OUTPUT
		INSERT INTO pi_app_react.app.pessoa VALUES(
			@id_novo_usuario, 
			@primeiro_nome, 
			@ultimo_nome, 
			@cpf, 
			@dta_nascimento, 
			@endereco, 
			@email, 
			@telefone
		 )
	
		SELECT @id_pessoa = MAX(pi_app_react.app.pessoa.id_pessoa)
		FROM pi_app_react.app.pessoa
	COMMIT
END TRY
BEGIN  CATCH
	IF @@TRANCOUNT > 0 ROLLBACK

	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH
GO

CREATE PROCEDURE app.insere_empresa
(
	@username VARCHAR(64),
	@password VARCHAR(64),
	@sigla VARCHAR(16),
	@nome VARCHAR(64),
	@des_empresa VARCHAR(64),
	@cnpj VARCHAR(64),
	@tipo_empresa VARCHAR(24),
	@endereco VARCHAR(128),
	@email VARCHAR(128),
	@telefone VARCHAR(32),
	@id_empresa INT = NULL OUTPUT
)
AS BEGIN TRY
	BEGIN TRANSACTION
		DECLARE @id_novo_usuario INT;
		EXEC pi_app_react.app.insere_usuario @username, @password, @id_novo_usuario OUTPUT
		INSERT INTO pi_app_react.app.empresa VALUES(
			@id_novo_usuario,
			@sigla,
			@nome,
			@des_empresa,
			@cnpj,
			@tipo_empresa,
			@endereco,
			@email,
			@telefone
		)
	
		SELECT @id_empresa = MAX(pi_app_react.app.empresa.id_empresa)
		FROM pi_app_react.app.empresa
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH
GO


-- \\ ~~ \\ \\ ~~ \\ \\ ~~ \\ \\ ~~ \\ PROCS DE SELECTS  \\ ~~ \\ \\ ~~ \\ \\ ~~ \\ \\ ~~ \\ \\ ~~ \\

CREATE PROCEDURE app.select_pessoa 
(
	@username VARCHAR(64)
)
AS BEGIN TRY
	BEGIN TRANSACTION
		SELECT * FROM pi_app_react.app.pessoa p
			INNER JOIN pi_app_react.app.usuario u
				ON u.id_usuario = p.id_usuario
		WHERE u.username = @username
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);	
END CATCH
GO

CREATE PROCEDURE app.select_empresa 
(
	@username VARCHAR(64)
)
AS BEGIN TRY
	BEGIN TRANSACTION
		SELECT * FROM pi_app_react.app.empresa e
			INNER JOIN pi_app_react.app.usuario u
				ON u.id_usuario = e.id_usuario
		WHERE u.username = @username
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);	
END CATCH
GO


CREATE PROCEDURE app.select_servico_por_empresa 
(
	@username VARCHAR(64),
	@status VARCHAR(32) = 'catalogo' 
)
AS BEGIN TRY
	BEGIN TRANSACTION
		SELECT s.* FROM pi_app_react.app.servico s
			INNER JOIN pi_app_react.app.empresa e
				ON e.id_empresa = s.id_empresa
			INNER JOIN pi_app_react.app.usuario u
				ON u.id_usuario = e.id_usuario
		WHERE 1 = 1
			AND u.username = 'empresa1'
			AND s.status = 'pago'
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);	
END CATCH
GO

CREATE PROCEDURE app.select_servico_por_pessoa 
(
	@username VARCHAR(64),
	@status VARCHAR(32) = 'contratado'
)
AS BEGIN TRY
	BEGIN TRANSACTION
		SELECT s.* FROM pi_app_react.app.servico s
			INNER JOIN pi_app_react.app.pessoa p
				ON p.id_pessoa = s.id_pessoa
			INNER JOIN pi_app_react.app.usuario u
				ON u.id_usuario = p.id_usuario
		WHERE 1 = 1
				AND u.username = @username
				AND s.status = @status
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);	
END CATCH
GO

CREATE PROCEDURE app.select_servico_por_categoria
(
	@categoria VARCHAR(256)
)
AS BEGIN TRY
	BEGIN TRANSACTION
		SELECT * FROM pi_app_react.app.servico s
		WHERE 1 = 1
			AND s.id_categoria = (
				SELECT id_categoria 
				FROM pi_app_react.app.categoria c 
				WHERE c.nome = @categoria
			)
			AND s.[status] = 'catalogo'
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH

-- \\ ~~ \\ \\ ~~ \\ \\ ~~ \\ \\ ~~ \\ PROCS DE UPDATES  \\ ~~ \\ \\ ~~ \\ \\ ~~ \\ \\ ~~ \\ \\ ~~ \\

CREATE PROCEDURE app.update_pessoa 
(
	@id_pessoa INT,
	@username VARCHAR(64),
	@password VARCHAR(64),
	@primeiro_nome VARCHAR(64),
	@ultimo_nome VARCHAR(64),
	@cpf VARCHAR(64),
	@dta_nascimento DATE,
	@endereco VARCHAR(128),
	@email VARCHAR(128),
	@telefone VARCHAR(32)
)
AS BEGIN TRY
	BEGIN TRANSACTION
	IF EXISTS (
		SELECT * FROM pi_app_react.app.pessoa p WHERE p.id_pessoa = @id_pessoa
	)
	BEGIN
		DECLARE @tmp_update_pessoa TABLE(
			username VARCHAR(64),
			[password] VARCHAR(64),
			primeiro_nome VARCHAR(64),
			ultimo_nome VARCHAR(64),
			cpf VARCHAR(64),
			dta_nascimento DATE,
			endereco VARCHAR(128),
			email VARCHAR(128),
			telefone VARCHAR(32)	
		);
		INSERT INTO @tmp_update_pessoa VALUES
		(
		 @username, @password, @primeiro_nome, 
		 @ultimo_nome, @cpf, @dta_nascimento, 
		 @endereco, @email, @telefone
		 )
		-- se existe alguma coluna com valor diferente, atualiza o registro
		IF EXISTS (
			SELECT * FROM @tmp_update_pessoa
			EXCEPT
			SELECT u.username,
				   u.[password],
				   pessoa.primeiro_nome,
				   pessoa.ultimo_nome,
				   pessoa.cpf,
				   pessoa.dta_nascimento,
				   pessoa.endereco,
				   pessoa.email,
				   pessoa.telefone
			FROM pi_app_react.app.pessoa pessoa
				INNER JOIN pi_app_react.app.usuario u
					ON u.id_usuario = pessoa.id_usuario
			WHERE pessoa.id_pessoa = @id_pessoa
		)
		BEGIN
			UPDATE pi_app_react.app.usuario
			SET username = tmp.username,
				[password] = tmp.[password]
			FROM @tmp_update_pessoa tmp
			WHERE id_usuario = (
				SELECT id_usuario 
				FROM pi_app_react.app.pessoa p 
				WHERE p.id_pessoa = @id_pessoa
			)

			UPDATE pi_app_react.app.pessoa 
			SET primeiro_nome = tmp.primeiro_nome,
				ultimo_nome = tmp.ultimo_nome,
				cpf = tmp.cpf,
				dta_nascimento = tmp.dta_nascimento,
				endereco = tmp.endereco,
				email = tmp.email,
				telefone = tmp.telefone
			FROM @tmp_update_pessoa tmp
			WHERE id_pessoa = @id_pessoa
		END
	END ELSE
	BEGIN
		DECLARE @Error NVARCHAR(4000) = 'Pessoa não encontrada', 
				@Severity INT = 16;
		RAISERROR(@Error, @Severity, 1);		
	END
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);	
END CATCH
GO

CREATE PROCEDURE app.update_empresa 
(
	@id_empresa INT,
	@username VARCHAR(64),
	@password VARCHAR(64),
	@sigla VARCHAR(16),
	@nome VARCHAR(64),
	@des_empresa VARCHAR(64),
	@cnpj VARCHAR(64),
	@tipo_empresa VARCHAR(24),
	@endereco VARCHAR(128),
	@email VARCHAR(128),
	@telefone VARCHAR(32)
)
AS BEGIN TRY
	BEGIN TRANSACTION
	IF EXISTS (
		SELECT * FROM pi_app_react.app.empresa e WHERE e.id_empresa = @id_empresa
	)
	BEGIN


		DECLARE @tmp_update_empresa TABLE(
			username VARCHAR(64),
			[password] VARCHAR(64),
			sigla VARCHAR(16),
			nome VARCHAR(64),
			des_empresa VARCHAR(64),
			cnpj VARCHAR(64),
			tipo_empresa VARCHAR(24),
			endereco VARCHAR(128),
			email VARCHAR(128),
			telefone VARCHAR(32)	
		);
		INSERT INTO @tmp_update_empresa VALUES
		(
		 @username, @password, 	@sigla, @nome, @des_empresa,
		 @cnpj, @tipo_empresa, @endereco, @email, @telefone
		 )
		-- se existe alguma coluna com valor diferente, atualiza o registro
		IF EXISTS (
			SELECT * FROM @tmp_update_empresa
			EXCEPT
			SELECT u.username,
				   u.[password],
				   empresa.sigla,
				   empresa.nome,
				   empresa.des_empresa,
				   empresa.cnpj,
				   empresa.tipo_empresa,
				   empresa.endereco,
				   empresa.email,
				   empresa.telefone
			FROM pi_app_react.app.empresa empresa
				INNER JOIN pi_app_react.app.usuario u
					ON u.id_usuario = empresa.id_usuario
			WHERE empresa.id_empresa = @id_empresa
		)
		BEGIN
			UPDATE pi_app_react.app.usuario
			SET username = tmp.username,
				[password] = tmp.[password]
			FROM @tmp_update_empresa tmp
			WHERE id_usuario = (
				SELECT id_usuario 
				FROM pi_app_react.app.empresa e 
				WHERE e.id_empresa = @id_empresa
			)

			UPDATE pi_app_react.app.empresa 
			SET sigla = tmp.sigla,
				nome = tmp.nome,
				des_empresa = tmp.des_empresa,
				cnpj = tmp.cnpj,
				tipo_empresa = tmp.tipo_empresa,
				endereco = tmp.endereco,
				email = tmp.email,
				telefone = tmp.telefone
			FROM @tmp_update_empresa tmp
			WHERE id_empresa = @id_empresa
		END
	END ELSE
	BEGIN
		DECLARE @Error NVARCHAR(4000) = 'Empresa não encontrada', 
				@Severity INT = 16;
		RAISERROR(@Error, @Severity, 1);
	END
	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), 
			@ErrorSeverity INT = ERROR_SEVERITY();
	RAISERROR(@ErrorMessage, @ErrorSeverity, 1);	
END CATCH
GO
