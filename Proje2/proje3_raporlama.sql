-- Gelişmiş ayarlar
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- Database Mail XPs’i açalım
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;

USE msdb;
GO

-- Var olan profiller
SELECT name, description
  FROM sysmail_profile;

-- Var olan hesaplar
SELECT name, email_address
  FROM sysmail_account;

  -- Database Mail profilini seçin
EXEC msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'Aymin',
    @description  = 'DBA raporları için';

EXEC msdb.dbo.sysmail_add_account_sp
    @account_name = 'DBMailAccount',
    @description  = 'SQL Server raporlama mail hesabı',
    @email_address= 'ayminayilik@gmail.com',
    @display_name = 'SQL Rapor',
    @mailserver_name = 'smtp.domain.com';

EXEC msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = 'Aymin',
    @account_name = 'Aymin',
    @sequence_number = 1;

-- Raporu mail ile gönder
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'Aymin',
    @recipients   = 'ayminayilik@gmail.com',
    @subject      = 'Günlük Yedek Raporu',
    @body         = 'Aşağıda son 24 saatte alınan yedekler yer almaktadır.',
    @body_format  = 'HTML',
    @query        = N'
        SELECT 
            database_name,
            backup_start_date,
            backup_finish_date,
            CASE type WHEN ''D'' THEN ''Full''
                      WHEN ''I'' THEN ''Diff''
                      WHEN ''L'' THEN ''Log''
            END AS backup_type,
            backup_size/1024/1024 AS size_mb,
            physical_device_name
        FROM msdb.dbo.backupset bs
        JOIN msdb.dbo.backupmediafamily mf
          ON bs.media_set_id = mf.media_set_id
        WHERE backup_start_date >= DATEADD(day,-1,GETDATE())
        ORDER BY backup_start_date DESC;
    ',
    @attach_query_result_as_file = 0;

