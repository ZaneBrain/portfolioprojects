--Verify Successful Import with Select All quieries
SELECT *
FROM HeadOffice

SELECT*
FROM Marketing

SELECT *
FROM Production

SELECT *
FROM CompanyStructure

SELECT *
FROM Taxonomy

SELECT *
FROM ExchangeRates

--Verify Currency Conversions in Excel with SQL for each Business Unit
--Head Office
SELECT 
	[Vendor Name], 
	Spend, 
	[Spend GBD], IIF([Rate] IS NOT NULL, Spend*Rate, Spend) AS SQL_GBP_Conversion, 
	YEAR(HeadOffice.Date) AS Year, 
	IIF([From] IS NOT NULL, [From], 'GBP') AS 'From', 
	IIF([To] IS NOT NULL, [To], 'GBP') AS 'To', 
	IIF(Rate IS NOT NULL, Rate, 1) AS RATE
FROM HeadOffice
LEFT JOIN ExchangeRates ON
HeadOffice.Currency = ExchangeRates.[From] AND YEAR(HeadOffice.Date) = ExchangeRates.Year
WHERE [Spend GBD] - IIF([Rate] IS NOT NULL, Spend*Rate, Spend) != 0

--Marketing
SELECT 
	[Vendor Name], 
	[USD Amount], 
	[Spend GBD], IIF([Rate] IS NOT NULL, [USD Amount]*Rate, [USD Amount]) AS SQL_GBP_Conversion, 
	YEAR(Marketing.Date) AS Year, 
	IIF([From] IS NOT NULL, [From], 'GBP') AS 'From', 
	IIF([To] IS NOT NULL, [To], 'GBP') AS 'To', 
	IIF(Rate IS NOT NULL, Rate, 1) AS RATE
FROM Marketing
LEFT JOIN ExchangeRates ON
Marketing.Currency = ExchangeRates.[From] AND YEAR(Marketing.Date) = ExchangeRates.Year
WHERE [Spend GBD] - IIF([Rate] IS NOT NULL, [USD Amount]*Rate, [USD Amount]) != 0

--Production
SELECT 
	[Vendor Name], 
	[Line Amount], 
	[Spend GBD], IIF([Rate] IS NOT NULL, [Line Amount]*Rate, [Line Amount]) AS SQL_GBP_Conversion, 
	YEAR(Production.Date) AS Year, 
	IIF([From] IS NOT NULL, [From], 'GBP') AS 'From', 
	IIF([To] IS NOT NULL, [To], 'GBP') AS 'To', 
	IIF(Rate IS NOT NULL, Rate, 1) AS RATE
FROM Production
LEFT JOIN ExchangeRates ON
Production.Currency = ExchangeRates.[From] AND YEAR(Production.Date) = ExchangeRates.Year
WHERE [Spend GBD] -IIF([Rate] IS NOT NULL, [Line Amount]*Rate, [Line Amount]) != 0

--Calculate the Total Spend for Each Business Unit
SELECT [Business Unit], SUM([Spend GBD]) AS 'Total Spent in GBP'
FROM HeadOffice
GROUP BY [Business Unit]
UNION
SELECT [Business Unit], SUM([Spend GBD]) AS 'Total Spent in GBP'
FROM Marketing
GROUP BY [Business Unit]
UNION
SELECT [Business Unit], SUM([Spend GBD]) AS 'Total Spent in GBP'
FROM Production
GROUP BY [Business Unit]


--Create a Table of Consolidated Business Units
DROP TABLE IF EXISTS AllBusinessUnits
CREATE TABLE AllBusinessUnits
(Supplier nvarchar(255),
Spend float,
Spend_GBP float,
Summary nvarchar(255),
Level_1 nvarchar(255),
Level_2 nvarchar(255),
Business_Unit nvarchar(255),
Location nvarchar(255),
Currency nvarchar(255),
Date datetime)

INSERT INTO AllBusinessUnits
SELECT *
FROM HeadOffice
UNION
SELECT *
FROM Marketing
UNION
SELECT *
FROM Production

SELECT *
From AllBusinessUnits

--Find amount of Spend Categorized by Level 1 in GBP
SELECT Level_1, SUM(Spend_GBP) AS 'Total Spend in GBP'
FROM AllBusinessUnits
GROUP BY Level_1
ORDER BY 'Total Spend in GBP' DESC

--Identify biggest supplier
SELECT Supplier, SUM(Spend_GBP) AS 'Total Spend in GBP'
FROM AllBusinessUnits
GROUP BY Supplier
ORDER BY 'Total Spend in GBP' DESC

--Identify percent contribution by currency
SELECT Currency,
SUM(Spend_GBP) AS 'Total Spent in GBP',
SUM(Spend_GBP)/(SELECT SUM(Spend_GBP) FROM AllBusinessUnits)*100 AS 'Percent Contribution'
FROM AllBusinessUnits
GROUP BY Currency
ORDER BY 'Percent Contribution' DESC

--Add Hong Kong to Company Structure as Asia-Pacific
SELECT *
FROM CompanyStructure

INSERT INTO CompanyStructure
VALUES (
'Hong Kong',
'Production',
'BFC Inc China',
'APAC')

SELECT *
FROM CompanyStructure

--Join Consolidated Business Unit Table and Company Structure Table to Find Spend by Region
SELECT Region, SUM(Spend_GBP) AS 'Total Spent in GBP'
FROM AllBusinessUnits
LEFT JOIN CompanyStructure ON
AllBusinessUnits.Location = CompanyStructure.Location
GROUP BY Region
ORDER BY 'Total Spent in GBP' DESC

--Find Spend by Location
SELECT Location, SUM(Spend_GBP) AS 'Total Spent in GBP'
FROM AllBusinessUnits
GROUP BY Location
ORDER BY 'Total Spent in GBP' DESC

--Create View for Tableau Visualizations

SELECT *
FROM AllBusinessUnits

DROP VIEW IF EXISTS BFC_Consolidation

CREATE VIEW BFC_Consolidation AS
SELECT 
	Supplier,
	Spend,
	Spend_GBP,
	Level_1,
	Level_2,
	Business_Unit,
	AllBusinessUnits.Location,
	Region,
	Currency,
	Date
FROM AllBusinessUnits
LEFT JOIN CompanyStructure ON
AllBusinessUnits.Location = CompanyStructure.Location

SELECT *
FROM BFC_Consolidation

SELECT SUM(Spend_GBP)
FROM AllBusinessUnits