/******************************************************
* 1. DW table
*******************************************************/
TRUNCATE TABLE dbo.dw_nmi_usage
GO

INSERT INTO dbo.dw_nmi_usage (AESTDate, AESTTime, AESTDateTime, Nmi, State, Unit, Interval, Quantity, Load_Timestamp)
SELECT 
	CAST(dw.AESTTime AS DATE) AS AESTDate, 
	CAST(dw.AESTTime AS TIME) AS AESTTime,
	dw.AESTTime AS AESTDateTime,
	dw.Nmi, 
	info.State, 
	dw.Unit,
	info.Interval,
	dw.Quantity,
	dw.Load_Timestamp
FROM dbo.stg_nmi_all AS dw
LEFT JOIN dbo.stg_nmi_info AS info
	ON dw.Nmi  = info.Nmi
GO



/******************************************************
* 2. Dimension tables
*******************************************************/
TRUNCATE TABLE dbo.dim_nmi_info;
GO

INSERT INTO dbo.dim_nmi_info (Nmi, State, Interval,Load_Timestamp)
SELECT Nmi, State, Interval,Load_Timestamp
FROM dbo.stg_nmi_info
GO;

-- dim date
TRUNCATE TABLE dbo.dim_date;
GO

DECLARE @StartDate  date = '20170101';
DECLARE @CutoffDate date = DATEADD(DAY, -1, DATEADD(YEAR, 2, @StartDate));
;WITH seq(n) AS 
(
  SELECT 0 UNION ALL SELECT n + 1 FROM seq
  WHERE n < DATEDIFF(DAY, @StartDate, @CutoffDate)
),
d(d) AS 
(
  SELECT DATEADD(DAY, n, @StartDate) FROM seq
),
src AS
(
  SELECT
	DateKey		 = CAST(format(d,'yyyyMMdd') as int),
    Date         = CONVERT(date, d),
    Day          = DATEPART(DAY,       d),
    DayName      = DATENAME(WEEKDAY,   d),
    Week         = DATEPART(WEEK,      d),
    ISOWeek      = DATEPART(ISO_WEEK,  d),
    DayOfWeek    = DATEPART(WEEKDAY,   d),
    Month        = DATEPART(MONTH,     d),
    MonthName    = DATENAME(MONTH,     d),
    Quarter      = DATEPART(Quarter,   d),
    Year         = DATEPART(YEAR,      d),
    FirstOfMonth = DATEFROMPARTS(YEAR(d), MONTH(d), 1),
    LastOfYear   = DATEFROMPARTS(YEAR(d), 12, 31),
    DayOfYear    = DATEPART(DAYOFYEAR, d)
  FROM d
)
INSERT INTO dbo.dim_date
SELECT * FROM src
ORDER BY Date
OPTION (MAXRECURSION 0)
;
GO

-- dim_time
TRUNCATE TABLE dbo.dim_time;
GO
DECLARE @Time as time;
SET @Time = '0:00'; 
DECLARE @counter as int;
SET @counter = 0;
-- Two variables to store the day part for two languages
DECLARE @daypartEN as varchar(20);
set @daypartEN = ''; 
DECLARE @daypartNL as varchar(20);
SET @daypartNL = '';
-- Loop 1440 times (24hours * 60minutes)
WHILE @counter < 1440
BEGIN
    -- Determine datepart
    SELECT  @daypartEN = CASE
                         WHEN (@Time >= '0:00' and @Time < '6:00') THEN 'Night'
                         WHEN (@Time >= '6:00' and @Time < '12:00') THEN 'Morning'
                         WHEN (@Time >= '12:00' and @Time < '18:00') THEN 'Afternoon'
                         ELSE 'Evening'
                         END
    ,       @daypartNL = CASE
                         WHEN (@Time >= '0:00' and @Time < '6:00') THEN 'Nacht'
                         WHEN (@Time >= '6:00' and @Time < '12:00') THEN 'Ochtend'
                         WHEN (@Time >= '12:00' and @Time < '18:00') THEN 'Middag'
                         ELSE 'Avond'
                         END;
 
    INSERT INTO dbo.dim_time ([Time]
                       , [Hour]
                       , [Minute]
                       , [MilitaryHour]
                       , [MilitaryMinute]
                       , [AMPM]
                       , [DayPartEN]
                       , [DayPartNL]
                       , [HourFromTo12]
                       , [HourFromTo24]
                       , [Notation12]
                       , [Notation24])
                VALUES (@Time
                       , DATEPART(Hour, @Time) + 1
                       , DATEPART(Minute, @Time) + 1
                       , DATEPART(Hour, @Time)
                       , DATEPART(Minute, @Time)
                       , CASE WHEN (DATEPART(Hour, @Time) < 12) THEN 'AM' ELSE 'PM' END
                       , @daypartEN
                       , @daypartNL
                       , CONVERT(varchar(10), DATEADD(Minute, -DATEPART(Minute,@Time), @Time),100)  + ' - ' + CONVERT(varchar(10), DATEADD(Hour, 1, DATEADD(Minute, -DATEPART(Minute,@Time), @Time)),100)
                       , CAST(DATEADD(Minute, -DATEPART(Minute,@Time), @Time) as varchar(5)) + ' - ' + CAST(DATEADD(Hour, 1, DATEADD(Minute, -DATEPART(Minute,@Time), @Time)) as varchar(5))
                       , CONVERT(varchar(10), @Time,100)
                       , CAST(@Time as varchar(5))
                       );
 
    -- Raise time with 15 minute
    SET @Time = DATEADD(minute, 15, @Time);
 
    -- Raise counter by one
    set @counter = @counter + 1;
END
GO

/******************************************************
* 3. Fact table 
*******************************************************/
TRUNCATE TABLE dbo.fact_nmi_usage
GO

INSERT INTO dbo.fact_nmi_usage (DateKey, TimeKey, NmiKey, Quantity_kWh, Total_Usage_kWh, Usage_Rate, Load_Timestamp)
SELECT
	DateKey,
	TimeKey,
	NmiKey,
	Quantity_kWh,
	SUM(Quantity_kWh) OVER (PARTITION BY DateKey, NmiKey) AS Total_Usage_kWh,
	(Quantity_kWh/ NULLIF(SUM(Quantity_kWh) OVER (PARTITION BY DateKey, NmiKey),0)) AS Usage_Rate, -- Use NULLIF to avoid divided by 0
	Load_Timestamp
FROM
(
	SELECT 
		dd.DateKey, 
		dt.TimeKey,
		info.NmiKey, 
		CASE -- convert quantity in different units to kwh
			WHEN UPPER(dw.Unit) = 'WH' THEN (dw.Quantity / 1000)  
			WHEN UPPER(dw.Unit) = 'MWH' THEN (dw.Quantity * 1000)
			ELSE dw.Quantity
		END AS Quantity_kWh,
		dw.Load_Timestamp
	FROM dbo.dw_nmi_usage AS dw
	LEFT JOIN dbo.dim_nmi_info AS info
		ON dw.Nmi = info.Nmi
	LEFT JOIN dbo.dim_date AS dd
		ON dw.AESTDate = dd.Date
	LEFT JOIN dbo.dim_time AS dt
		ON dw.AESTTime = dt.time
) a
GO


