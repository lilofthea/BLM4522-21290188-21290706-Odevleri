--------------------------------------------------------------------------------
-- Bölüm 1: Sürüm ve Uyumluluk Bilgileri
--------------------------------------------------------------------------------
-- SQL Server versiyonunu öğrenme
SELECT @@VERSION;

-- Veritabanı uyumluluk seviyelerini kontrol etme
SELECT name,
       compatibility_level
FROM sys.databases;


--------------------------------------------------------------------------------
-- Bölüm 2: Veritabanı Yedek Listeleme
--------------------------------------------------------------------------------
-- Yedek dosyasındaki dosya listesine bakma
RESTORE FILELISTONLY
FROM DISK = 'C:\Backups\NorthDB_Full.bak';


--------------------------------------------------------------------------------
-- Bölüm 3: Şema Değişikliklerini Denetleme (Audit)
--------------------------------------------------------------------------------
-- 3.1. Audit Tablosu
CREATE TABLE dbo.SchemaChangeLog
(
    ChangeID      INT IDENTITY(1,1) PRIMARY KEY,
    EventTime     DATETIME      NOT NULL DEFAULT SYSUTCDATETIME(),
    EventType     NVARCHAR(100) NOT NULL,
    ObjectName    NVARCHAR(255),
    SqlCommand    NVARCHAR(MAX),
    LoginName     NVARCHAR(128),
    HostName      NVARCHAR(128)
);

-- 3.2. DDL Trigger
CREATE TRIGGER trg_DDL_SchemaChange
ON DATABASE
AFTER DDL_DATABASE_LEVEL_EVENTS
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.SchemaChangeLog
        (EventType, ObjectName, SqlCommand, LoginName, HostName)
    SELECT
        EVENTDATA().value('(/EVENT_INSTANCE/EventType)[1]',       'NVARCHAR(100)'),
        EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]',      'NVARCHAR(255)'),
        EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)'),
        ORIGINAL_LOGIN(),
        HOST_NAME();
END;
GO


--------------------------------------------------------------------------------
-- Bölüm 4: Basit Transaction / Rollback Örneği
--------------------------------------------------------------------------------
BEGIN TRANSACTION;
    -- Örnek: Şema değişikliği
    ALTER TABLE Orders
      ADD OrderStatus TINYINT NOT NULL DEFAULT(0);
COMMIT;
-- Sorun olursa:
-- ROLLBACK;
GO


--------------------------------------------------------------------------------
-- Bölüm 5: Veritabanı ve Tablo Oluşturma / Ön Kontroller
--------------------------------------------------------------------------------
USE master;
GO
IF DB_ID('TestDB') IS NULL
    CREATE DATABASE TestDB;
GO

USE TestDB;
GO

IF OBJECT_ID('dbo.Orders','U') IS NOT NULL
    DROP TABLE dbo.Orders;
GO

CREATE TABLE dbo.Orders
(
    OrderID      INT          IDENTITY(1,1) PRIMARY KEY,
    OrderDate    DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    OrderStatus  TINYINT      NOT NULL DEFAULT(0)
);
GO

-- Örnek kayıt eklemeleri
INSERT INTO dbo.Orders DEFAULT VALUES;
INSERT INTO dbo.Orders DEFAULT VALUES;
SELECT * FROM dbo.Orders;
GO


--------------------------------------------------------------------------------
-- Bölüm 6: Kolon Ekleme ve INFORMATION_SCHEMA Kontrolü
--------------------------------------------------------------------------------
BEGIN TRANSACTION;
    ALTER TABLE dbo.Orders
      ADD ShipmentDate DATETIME2 NULL;

    -- Değişikliği kontrol etmek için:
    SELECT COLUMN_NAME,
           DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Orders';
COMMIT TRANSACTION;
GO

-- Eğer geri almak isterseniz:
-- ROLLBACK TRANSACTION;
-- GO

-- Geri alındığını kontrol etme
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Orders';
GO


--------------------------------------------------------------------------------
-- Bölüm 7: Snapshot Veritabanı Oluşturma
--------------------------------------------------------------------------------
-- Northwind veritabanının snapshot'ını yaratma
CREATE DATABASE Northwind_Snap
ON
  ( NAME = Northwind,
    FILENAME = 'C:\Snapshots\Northwind_Snap.ss' )
AS SNAPSHOT OF Northwind;
GO

-- Northwind veritabanını 'Northwind_Snap' isimli snapshot’a geri döndür
RESTORE DATABASE Northwind
FROM DATABASE_SNAPSHOT = 'Northwind_Snap';
GO
