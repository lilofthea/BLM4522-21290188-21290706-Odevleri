-- Northwind boyutu
SELECT 
  SUM(size) * 8.0/1024 AS [Size_MB]
FROM sys.database_files;

-- Bellek kullanımı
SELECT 
  object_name,
  counter_name,
  cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy';



-- Mevuct indeksleri görelim
SELECT
  OBJECT_NAME(i.object_id) AS TableName,
  i.name AS IndexName,
  ips.avg_fragmentation_in_percent
FROM sys.indexes i
JOIN sys.dm_db_index_physical_stats(DB_ID('NorthwindDB'), NULL, NULL, NULL, 'LIMITED') ips
  ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE OBJECT_NAME(i.object_id) IN ('Orders','Order Details','Products')
  AND ips.avg_fragmentation_in_percent > 30;

-- Bekleyen (wait) istatistiklerini inceleme
SELECT 
    wait_type,
    waiting_tasks_count,
    wait_time_ms/1000.0 AS toplam_bekleme_saniye,
    max_wait_time_ms/1000.0 AS maksimum_bekleme_saniye
FROM sys.dm_os_wait_stats
WHERE waiting_tasks_count > 0
  AND wait_type NOT IN ('CLR_SEMAPHORE','LAZYWRITER_SLEEP','SLEEP_TASK','BROKER_TO_FLUSH','SQLTRACE_BUFFER_FLUSH')
ORDER BY wait_time_ms DESC;

-- En fazla CPU/çeşitli kaynağı kullanan sorguları listeleme
SELECT TOP 20
    qs.sql_handle,
    qs.execution_count,
    qs.total_worker_time AS toplam_cpu_ms,
    qs.total_elapsed_time/1000 AS toplam_sure_saniye,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset END
         - qs.statement_start_offset)/2)+1) AS sql_text,
    qp.query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
ORDER BY qs.total_worker_time DESC;

-- Tablolardaki indeks kırılma (fragmentation) oranlarını kontrol etme
SELECT
    OBJECT_NAME(ps.object_id) AS tablo,
    i.name AS indeks,
    ps.index_id,
    ps.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
JOIN sys.indexes AS i
    ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE ps.database_id = DB_ID()
  AND ps.avg_fragmentation_in_percent > 10
ORDER BY ps.avg_fragmentation_in_percent DESC;

-- Kırık indeksleri yeniden oluşturma (Rebuild) veya organize etme (Reorganize)
SET NOCOUNT ON;

DECLARE 
    @SchemaName SYSNAME,
    @TableName  SYSNAME,
    @IndexName  SYSNAME,
    @Frag        FLOAT;

DECLARE index_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT 
        OBJECT_SCHEMA_NAME(ps.object_id, DB_ID()) AS SchemaName,
        OBJECT_NAME(ps.object_id, DB_ID())        AS TableName,
        i.name                                     AS IndexName,
        ps.avg_fragmentation_in_percent            AS Frag
    FROM sys.dm_db_index_physical_stats(
            DB_ID(), NULL, NULL, NULL, 'LIMITED'
         ) AS ps
    INNER JOIN sys.indexes AS i
        ON ps.object_id = i.object_id
       AND ps.index_id  = i.index_id
    WHERE ps.avg_fragmentation_in_percent > 10
      AND i.type_desc <> 'HEAP';  -- HEAP için indeks yok
OPEN index_cursor;

FETCH NEXT FROM index_cursor 
INTO @SchemaName, @TableName, @IndexName, @Frag;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @Frag > 30
        EXEC(
          'ALTER INDEX [' + @IndexName + '] ON [' 
          + @SchemaName + '].[' + @TableName + '] REBUILD;'
        );
    ELSE
        EXEC(
          'ALTER INDEX [' + @IndexName + '] ON [' 
          + @SchemaName + '].[' + @TableName + '] REORGANIZE;'
        );

    FETCH NEXT FROM index_cursor 
    INTO @SchemaName, @TableName, @IndexName, @Frag;
END
CLOSE index_cursor;
DEALLOCATE index_cursor;


-- Hiç kullanılmayan indeksleri tespit etme
SELECT 
    OBJECT_NAME(s.object_id) AS tablo,
    i.name AS indeks,
    s.user_seeks + s.user_scans + s.user_lookups + s.user_updates AS kullanim_sayisi
FROM sys.dm_db_index_usage_stats AS s
JOIN sys.indexes AS i
    ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE database_id = DB_ID()
  AND s.user_seeks + s.user_scans + s.user_lookups = 0
  AND i.is_primary_key = 0
ORDER BY kullanim_sayisi ASC;


-- Veri tabanı ve dosya boyutlarını kontrol etme
EXEC sp_spaceused;  -- genel özet

-- 3.2. Her bir veri dosyasının fiziksel boyutu
SELECT
    name AS mantıksal_ad,
    physical_name,
    size/128.0 AS boyut_MB,
    growth/128.0 AS büyüme_adimi_MB
FROM sys.master_files
WHERE database_id = DB_ID();


-- İstatistik güncelleme ile sorgu planlarını tazeleme
EXEC sp_updatestats;  

-- Belirli bir tablo için tam istatistik güncelleme
UPDATE STATISTICS dbo.Categories WITH FULLSCAN;


-- Filtreli ya da kapsayıcı (covering) indeks önerisi almak için DMV
SELECT TOP 20
    DB_NAME(mid.database_id) AS DatabaseName,
    OBJECT_NAME(mid.object_id, mid.database_id) AS TableName,
    mid.equality_columns AS EqualityColumns,
    mid.inequality_columns AS InequalityColumns,
    mid.included_columns AS IncludedColumns,
    migs.unique_compiles AS CompileCount,
    migs.user_seeks AS UserSeeks,
    migs.user_scans AS UserScans,
    migs.avg_total_user_cost AS AvgTotalCost,
    migs.avg_user_impact AS AvgUserImpact
FROM sys.dm_db_missing_index_details   AS mid
JOIN sys.dm_db_missing_index_groups    AS mig
    ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats AS migs
    ON mig.index_group_handle = migs.group_handle
ORDER BY migs.avg_user_impact DESC;  


-- Tablo veri sıkıştırma 
ALTER TABLE dbo.Orders
REBUILD WITH (DATA_COMPRESSION = ROW);


-- Yeni bir rol oluşturma
CREATE ROLE db_DataAnalyst;

-- Role SELECT izni verme
GRANT SELECT ON SCHEMA :: dbo TO db_DataAnalyst;

-- Role EXECUTE izni verme (stored procedure’lar için)
GRANT EXECUTE ON SCHEMA :: dbo TO db_DataAnalyst;

-- Bireysel kullanıcıyı role atama
ALTER ROLE db_DataAnalyst ADD MEMBER aymin;
