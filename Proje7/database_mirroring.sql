-- Veritabanýný FULL recovery mode'a almak
ALTER DATABASE northwind SET RECOVERY FULL;

--FULL ve TRANSACTION BACKUP al (PRINCIPAL sunucuda)
BACKUP DATABASE northwind TO DISK = 'C:\SQL2022\Backup\veritabani_full.bak';
BACKUP LOG northwind TO DISK = 'C:\SQL2022\Backup\veritabani_log.trn';

--Mirror sunucuya bu yedekleri yükle (NORECOVERY ile!)
RESTORE DATABASE northwind
FROM DISK = 'C:\SQL2022\Backup\veritabani_full.bak'
WITH NORECOVERY;

RESTORE LOG northwind
FROM DISK = 'C:\SQL2022\Backup\veritabani_log.trn'
WITH NORECOVERY;

-- **Endpoint Oluþtur (Her iki sunucuda da)**

-- Principal Sunucu
CREATE ENDPOINT MirroringEndpoint
STATE = STARTED
AS TCP (LISTENER_PORT = 5022)
FOR DATABASE_MIRRORING (
    ROLE = PARTNER
);

-- Mirror Sunucu
CREATE ENDPOINT MirroringEndpoint
STATE = STARTED
AS TCP (LISTENER_PORT = 5022)
FOR DATABASE_MIRRORING (
    ROLE = PARTNER
);

--Sunuculara login yetkisi ver
-- Principal'da:
CREATE LOGIN [MIRROR\sqlserviceaccount] FROM WINDOWS;
GRANT CONNECT ON ENDPOINT::MirroringEndpoint TO [MIRROR\sqlserviceaccount];

-- Mirror'da:
CREATE LOGIN [PRINCIPAL\sqlserviceaccount] FROM WINDOWS;
GRANT CONNECT ON ENDPOINT::MirroringEndpoint TO [PRINCIPAL\sqlserviceaccount];

-- Mirroring Baþlat
ALTER DATABASE northwind
SET PARTNER = 'TCP://mirrorserver:5022';

ALTER DATABASE northwind
SET PARTNER = 'TCP://principalserver:5022';

--Durumu Kontrol Et
SELECT
    database_id,
    mirroring_state_desc,
    mirroring_role_desc,
    mirroring_partner_instance
FROM sys.database_mirroring
WHERE database_id = DB_ID('northwind');

