
SELECT CompanyName, Phone FROM Customers;

UPDATE Customers
SET Phone = REPLACE(REPLACE(REPLACE(REPLACE(
REPLACE(Phone, '.', ''), '-', ''), '(', ''), ')', ''), ' ', '');

UPDATE Customers
SET Phone = NULL
WHERE ISNUMERIC(Phone) = 0

UPDATE Customers
SET Phone = RIGHT(Phone, LEN(Phone) - 1)
WHERE LEFT(Phone, 1) = '0' AND LEN(Phone) = 11;

SELECT * FROM Customers
WHERE LEN(Phone) != 10;

SELECT 
  COUNT(*) AS InvalidPhoneCount
FROM CleanedCustomers
WHERE LEN(Phone) != 10 OR ISNUMERIC(Phone) = 0;