-- ============================================================================
-- 1. NULL Değer Kontrolü
-- ============================================================================
SELECT *
FROM Customers
WHERE Address IS NULL
   OR Fax IS NULL;


-- ============================================================================
-- 2. Geçersiz Telefon Numaralarını Listeleme (Standardizasyon Öncesi)
-- ============================================================================
SELECT CompanyName,
       Phone
FROM Customers
WHERE LEN(Phone) < 10
   OR Phone NOT LIKE '[0-9]%';


-- ============================================================================
-- 3. Telefon ve Fax’tan Özel Karakterlerin Çıkarılması
-- ============================================================================
UPDATE Customers
SET Phone = REPLACE(
               REPLACE(
                 REPLACE(
                   REPLACE(
                     REPLACE(
                       REPLACE(Phone, '.', ''),
                       '-', ''
                     ),
                     '(', ''
                   ),
                   ')', ''
                 ),
                 ' ', ''
               ),
               '/', ''
             );

UPDATE Customers
SET Fax = REPLACE(
             REPLACE(
               REPLACE(
                 REPLACE(
                   REPLACE(
                     REPLACE(Fax, '.', ''),
                     '-', ''
                   ),
                   '(', ''
                 ),
                 ')', ''
               ),
               ' ', ''
             ),
             '/', ''
           );


-- ============================================================================
-- 4. Ön Ek Olarak Gelen Sıfırların Kaldırılması (11 Haneli Numara)
-- ============================================================================
UPDATE Customers
SET Phone = RIGHT(Phone, LEN(Phone) - 1)
WHERE LEFT(Phone, 1) = '0'
  AND LEN(Phone) = 11;


-- ============================================================================
-- 5. Temizlenmiş Veriyi Yeni Tabloda Birleştirme (ETL İşlemi)
-- ============================================================================
INSERT INTO CleanedCustomers (
    CustomerID,
    CompanyName,
    ContactName,
    ContactTitle,
    Address,
    City,
    Region,
    PostalCode,
    CountryStandardized,
    PhoneStandardized,
    FaxStandardized
)
SELECT
    c.CustomerID,
    c.CompanyName,
    c.ContactName,
    c.ContactTitle,
    c.Address,
    c.City,
    c.Region,
    c.PostalCode AS PostalCode,  -- Temizlenmiş PostalCode
    CASE
      WHEN c.Country = 'USA' THEN 'United States'
      WHEN c.Country = 'UK'  THEN 'United Kingdom'
      -- Diğer ülke standartlaştırmalarını buraya ekleyin
      ELSE c.Country
    END AS CountryStandardized,
    -- Telefon numarası standardize etme (sadece rakamları alıp istenen formata sokma)
    CASE
      WHEN c.Phone IS NOT NULL
           AND c.Phone <> ''
      THEN c.Phone  -- Buraya regex/CLR fonksiyonu ile format ekleyebilirsiniz
      ELSE NULL
    END AS PhoneStandardized,
    -- Fax için benzer işlem
    CASE
      WHEN c.Fax IS NOT NULL
           AND c.Fax <> ''
      THEN c.Fax
      ELSE NULL
    END AS FaxStandardized
FROM Customers AS c;


-- ============================================================================
-- 6. Telefon Numarası Format Değişikliği Raporu
--    - Standardizasyon Öncesi Geçersiz Telefon Sayısı
-- ============================================================================
SELECT
  'Before Standardization' AS ReportType,
  COUNT(*) AS InvalidPhoneFormatCount
FROM Customers
WHERE Phone IS NOT NULL
  AND Phone <> ''
  AND (
        Phone NOT LIKE '[0-9]%'
        OR LEN(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Phone, '.', ''), '-', ''), '(', ''), ')', ''), ' ', ''), '/', '')) < 10
      );

--    - Standardizasyon Sonrası Geçersiz Telefon Sayısı
SELECT
  'After Standardization' AS ReportType,
  COUNT(*) AS InvalidPhoneFormatCount
FROM CleanedCustomers
WHERE PhoneStandardized IS NOT NULL
  AND PhoneStandardized <> ''
  AND LEN(PhoneStandardized) < 10;  -- Eğer 10 haneli olmasını bekliyorsak


-- ============================================================================
-- 7. Ülke Standartlaştırma Raporu
--    - Kaç Farklı Ülke Adı Vardı?
-- ============================================================================
SELECT
  'Before Standardization' AS ReportType,
  COUNT(DISTINCT Country) AS DistinctCountries
FROM Customers;

SELECT
  'After Standardization' AS ReportType,
  COUNT(DISTINCT CountryStandardized) AS DistinctCountries
FROM CleanedCustomers;

--    - Standartlaştırılan Ülke Dağılımı
SELECT
  CountryStandardized,
  COUNT(*) AS RecordCount
FROM CleanedCustomers
GROUP BY CountryStandardized
ORDER BY RecordCount DESC;


-- ============================================================================
-- 8. Son Kontrol: Temizlenmiş ve Orijinal Tablo İncelemesi
-- ============================================================================
SELECT * FROM Customers;
SELECT * FROM CleanedCustomers;
