-- Recovery Full moduna geçilir

ALTER DATABASE NorthwindDB
SET RECOVERY FULL;
GO

-- Periyodik yedeklemeleri SQL Server Agent üzerinden ekliyoruz 

-- Kaza anını simüle edelim
USE NorthwindDB;
GO

select * from orders
DELETE FROM orders
WHERE OrderDate < '1997-04-21';  
-- Bu komutu 19.30'da çalıştırmış olalım.
GO

-- Kaza öncesi olan tüm logları alalım, bunu yapmak için bağlantımızı değiştirmemiz gerekiyor

USE Master;
GO

-- Full Backup’tan geri yükle , diğerleri de aynı şekilde yapılır.
RESTORE DATABASE NorthwindDB
FROM DISK = N'C:\DBBackup\NorthwindDB_Full.bak'
WITH REPLACE, NORECOVERY;
GO

-- Differential Backup’tan geri yükleme
RESTORE DATABASE NorthwindDB
FROM DISK = N'C:\DBBackup\NorthwindDB_Diff.bak'
WITH NORECOVERY;
GO

-- Transaction Log Backup’tan geri yükleme
BACKUP LOG NorthwindDB
TO DISK = N'C:\DBBackup\NorthwindDB_log.trn'
WITH NOFORMAT, NOINIT,
     NAME = N'NorthwindDB_log_hourly',
     STATS = 5;
GO

-- Tail-Log yedeğini de kazadan hemen öncesine (STOPAT) getirecek şekilde RECOVERY ile yükleyebiliriz
RESTORE LOG NorthwindDB
FROM DISK = N'C:\DBBackup\NorthwindDB_Tail.trn'
WITH STOPAT = '2025-04-19 19:30:00',  -- kaza öncesi son anı buraya yazıyoruz
     RECOVERY;
GO

RESTORE DATABASE NorthwindDB
WITH RECOVERY;
GO

-- Silinen kayıtların geri geldiğini doğrulayalım
USE NorthwindDB;
GO

SELECT COUNT(*) 
FROM orders
WHERE OrderDate < '1997-04-21';
GO
