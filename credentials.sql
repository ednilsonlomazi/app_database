USE master;
GO

IF DB_ID('pi_app_react') IS NOT NULL
BEGIN
	DROP DATABASE pi_app_react;
END

CREATE DATABASE pi_app_react;
GO

USE pi_app_react;
GO

IF NOT EXISTS (
	SELECT * FROM master.sys.server_principals ssp
	WHERE ssp.name = 'login_usuario_app'
)
BEGIN
	CREATE LOGIN login_usuario_app   
	WITH PASSWORD = 'senha', DEFAULT_DATABASE=[pi_app_react];
END
GO

CREATE USER usuario_app FOR LOGIN login_usuario_app;  
GO   

GRANT SELECT, 
	  UPDATE, 
	  DELETE, 
	  INSERT, 
	  CREATE TABLE, 
	  CREATE PROC, 
	  CREATE VIEW,
	  CREATE SCHEMA,
	  CONNECT,
	  EXECUTE

	  ON DATABASE::pi_app_react TO usuario_app 
	  WITH GRANT OPTION;
GO

CREATE SCHEMA app AUTHORIZATION [usuario_app];
GO

ALTER USER [usuario_app] WITH DEFAULT_SCHEMA=[app];
GO
