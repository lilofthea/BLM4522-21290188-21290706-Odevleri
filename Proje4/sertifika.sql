USE northwind
GO



USE master;
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Password123';
GO

CREATE CERTIFICATE TDECert
WITH SUBJECT = 'Veri þifreleme için sertifika';
GO

USE northwind; 
GO

CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDECert;


ALTER DATABASE northwind
SET ENCRYPTION ON;

SELECT 
    db.name AS DatabaseName,
    dm.encryption_state,
    dm.percent_complete,
    dm.key_algorithm,
    dm.key_length
FROM sys.dm_database_encryption_keys dm
JOIN sys.databases db
    ON dm.database_id = db.database_id;

BACKUP CERTIFICATE TDECert
TO FILE = 'C:\SQL2022\Backup\TDECert.cer'
WITH PRIVATE KEY (
    FILE = 'C:\SQL2022\Backup\TDECertPrivateKey.pvk',
    ENCRYPTION BY PASSWORD = 'Backup123'
);

USE master;
GO

SELECT name, subject
FROM sys.certificates
WHERE name = 'TDECert';