--Data exploration by Location
--International and Northern Cyprus have NULL values for their populations
--Location isn't just countries: World, Asia, Lower middle income, Upper middle income, Africa, High income, Europe, Low income
--North America, European Union, South America, International
--All of these have a NULL continent
SELECT continent, location, MAX(population) AS Max_Pop
FROM [covid deaths]
GROUP BY continent, location
ORDER BY Max_Pop desc


--Current Probability of death if COVID has been contracted, by country
SELECT location, date, population, total_cases, total_deaths, (total_deaths/total_cases)*100 AS percent_died
FROM [Covid Portfolio Project]..[covid deaths]
WHERE continent IS NOT NULL
ORDER BY 2 desc, 1 

--Total cases by population (not accounting for repeat cases)
SELECT location, date, population, total_cases, (total_cases/population)*100 AS percent_contracted
FROM [covid deaths]
WHERE continent IS NOT NULL 
ORDER BY 2 desc, 1

--Countries with Highest Infection Rate Compared to Population
SELECT location, MAX(total_cases) AS greatest_number_infected, MAX(total_cases/population) AS percent_pop_infected
FROM [covid deaths]
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY 3 desc

--Countries with Highest Mortality (North Korea is an Outlier—6 deaths reported, but only 1 case reported)
SELECT location, MAX(total_deaths) AS total_deaths, MAX(total_cases) AS total_cases, MAX(total_deaths)/MAX(total_cases) AS chance_of_death
FROM [covid deaths]
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY 4 desc

--North Korea sees its first case reported on 14/5/2022 in this data, with reports of 6 deaths coinciding
--Presumably this is due to unreliable reporting
SELECT location, date, total_cases, total_deaths
FROM [covid deaths]
WHERE location = 'North Korea'
ORDER BY 4 desc, 3 desc, 2

--Calculating statistics by Continent
--Percent contracted
SELECT location, date, population, total_cases, (total_cases/population)*100 AS percent_contracted
FROM [covid deaths]
WHERE continent IS  NULL 
ORDER BY 1, 2

--Continents with Highest Infection Rate Compared to Population
SELECT location, MAX(total_cases) AS greatest_number_infected, MAX(total_cases/population) AS percent_pop_infected
FROM [covid deaths]
WHERE continent IS NULL and location NOT IN ('World', 'High Income', 'Upper middle income', 'Lower middle income', 'Low income', 'International')
GROUP BY location
ORDER BY 2 desc, 1

--Finding the amount of new cases and deaths globally by day
SELECT date, SUM(new_cases) AS case_total, SUM(new_deaths) AS death_total, SUM(new_deaths)/sum(new_cases) AS mortality_ratio
FROM [covid deaths]
WHERE continent IS NOT NULL
GROUP BY date
order by 4 desc

--Finding the total global mortality
SELECT MAX(total_cases) AS Total_Cases, MAX(total_deaths) AS Total_Deaths, MAX(total_deaths)/MAX(total_cases)*100 AS Overall_Mortality
FROM [covid deaths]

--Finding the total global mortality
SELECT SUM(new_cases) AS Total_Cases, SUM(new_deaths) AS Total_Deaths, SUM(new_deaths)/SUM(new_cases)*100 AS Overall_Mortality
FROM [covid deaths]
WHERE continent IS NOT NULL 

--Testing table join
SELECT *
FROM [covid deaths] death
JOIN [covid vaccinations] vac
	ON death.location = vac.location
	and death.date = vac.date 

--Total Population vs Vaccinations
SELECT death.location, death.date, death.population, new_vaccinations, 
	SUM(new_vaccinations) OVER (Partition by death.location ORDER BY death.location, death.date) AS running_total_vac
FROM [covid deaths] death
JOIN [covid vaccinations] vac
	ON death.location = vac.location
	and death.date = vac.date 
WHERE death.continent IS NOT NULL 
ORDER BY 1, 2


--Creating a Common Table Expression of the above query

With PopvsVac (Location, Date, Population, New_Vaccinations, Rolling_Total_Vac)
AS
(
	SELECT death.location, death.date, death.population, new_vaccinations, 
		SUM(new_vaccinations) OVER (Partition by death.location ORDER BY death.location, death.date) AS running_total_vac
	FROM [covid deaths] death
	JOIN [covid vaccinations] vac
		ON death.location = vac.location
		and death.date = vac.date 
	WHERE death.continent IS NOT NULL 
)
SELECT *, (Rolling_Total_Vac/Population)*100
FROM PopvsVac 

--Creating a Temporary Table of the above query
DROP TABLE IF EXISTS #PoptoVac
CREATE TABLE #PoptoVac
(Location nvarchar(255),
Date datetime,
Population numeric,
New_Vaccinations numeric,
Running_Total_Vac numeric
)
INSERT INTO #PoptoVac
SELECT death.location, death.date, death.population, new_vaccinations, 
	SUM(new_vaccinations) OVER (Partition by death.location ORDER BY death.location, death.date) AS running_total_vac
FROM [covid deaths] death
JOIN [covid vaccinations] vac
	ON death.location = vac.location
	and death.date = vac.date 
WHERE death.continent IS NOT NULL 

SELECT *, (Running_Total_Vac/Population)*100 AS Percent_Vac --There is a point where the number of vaccinations exceeds the population in the U.S. indicated that repeat vaccinations are likely included
FROM #PoptoVac

--Find the difference in new cases from the day before
SELECT location, date, new_cases, (new_cases - LAG(new_cases) OVER (PARTITION BY location ORDER BY date)) AS difference_daily_cases 
FROM [covid deaths]
WHERE continent IS NOT NULL
ORDER BY 1, 2

--Creating a Temporary Table of the above
DROP TABLE IF EXISTS #PercentChangeCases
CREATE TABLE #PercentChangeCases
(location nvarchar(255),
date datetime,
new_cases numeric,
previous_cases numeric,
difference_daily_cases numeric,
percent_change numeric
)
INSERT INTO #PercentChangeCases
SELECT
location, 
date, 
new_cases, 
LAG(new_cases) OVER (PARTITION BY location ORDER BY date) AS previous_cases, 
(new_cases - LAG(new_cases) OVER (PARTITION BY location ORDER BY date)) AS difference_daily_cases,
100* (new_cases - LAG(new_cases) OVER (PARTITION BY location ORDER BY date))/(NULLIF(LAG(new_cases) OVER (PARTITION BY location ORDER BY date),0)) AS percent_change
FROM [covid deaths]
WHERE continent IS NOT NULL

--Joining Percent Change Info on Vaccination Info
SELECT *
FROM #PercentChangeCases
JOIN [covid vaccinations] vac
	ON #PercentChangeCases.date = vac.date and #PercentChangeCases.location = vac.location
WHERE vac.location = 'United States'


--Creating Views for later Viz

--Create view to compare number of daily cases and deaths to percent vaccinated
DROP VIEW IF EXISTS DeathVacPercent
CREATE VIEW DeathVacPercent AS
SELECT death.location, 
death.date, 
death.population, 
new_cases,
new_deaths,
people_vaccinated, 
(people_vaccinated/death.population)*100 AS percent_vaccinated
FROM [covid deaths]death
JOIN [covid vaccinations] vac
	ON death.location = vac.location
	and death.date = vac.date
WHERE death.continent IS NOT NULL
