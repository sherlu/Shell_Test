-- USE shell
-- GO

/******************************************************
*  1. Create staging tables
*******************************************************/
DROP TABLE IF EXISTS dbo.stg_nmi_info
GO

CREATE TABLE dbo.stg_nmi_info(
	Nmi varchar(50) NULL,
	State varchar(50) NULL,
	Interval integer NULL,
	Load_Timestamp datetime NULL
)
GO

DROP TABLE IF EXISTS dbo.stg_nmi_info_error
GO

CREATE TABLE dbo.stg_nmi_info_error(
	Nmi varchar(200) NULL,
	State varchar(200) NULL,
	Load_Timestamp varchar(200) NULL,
	Interval integer NULL,
	Error text NULL
)
GO

DROP TABLE IF EXISTS dbo.stg_nmi_all
GO

CREATE TABLE dbo.stg_nmi_all(
	AESTTime datetime NULL,
	Quantity decimal(28, 2) NULL,
	Unit varchar(50) NULL,
	Nmi varchar(50) NULL,
	Load_Timestamp datetime NULL
)
GO


DROP TABLE IF EXISTS dbo.stg_nmi_all_error
GO

CREATE TABLE dbo.stg_nmi_all_error(
	AESTTime  varchar(200) NULL,
	Quantity varchar(200) NULL,
	Unit varchar(200) NULL,
	Nmi varchar(200) NULL,
	Load_Timestamp varchar(200) NULL,
	Error text NULL
)
GO


/******************************************************
* 2. Create DW table
*******************************************************/
DROP TABLE IF EXISTS dbo.dw_nmi_usage
GO

CREATE TABLE dbo.dw_nmi_usage(
	NmiUsageId int IDENTITY(1,1) NOT NULL,
	AESTDate date NOT NULL,
	AESTTime time(0) NOT NULL,
	AESTDateTime datetime NOT NULL,
	Nmi varchar(50) NOT NULL,
	State varchar(50) NULL,
	Unit varchar(50) NULL,
	Interval integer NULL,
	Quantity decimal(28, 2) NULL,
	Load_Timestamp datetime NOT NULL
)



/******************************************************
* 3. Create dimension tables 
*******************************************************/
DROP TABLE IF EXISTS dbo.dim_nmi_info
GO

CREATE TABLE dbo.dim_nmi_info(
	NmiKey int IDENTITY(1,1) NOT NULL,
	Nmi varchar(50) NULL,
	State varchar(50) NULL,
	Interval integer NULL,
	Load_Timestamp datetime NULL
)
GO


DROP TABLE IF EXISTS dbo.dim_date
GO

CREATE TABLE dbo.dim_date(
    DateKey int NOT NULL,
    Date date NULL,
    Day [int] NULL,
    DayName [varchar](20) NULL,
    Week int null,
	ISOWeek int null,
    DayOfWeek int null,
    Month int NULL,
    MonthName [varchar](20) NULL,
    Quarter int NULL,
    Year int NULL,
	FirstOfMonth date NULL,
    LastOfYear date NULL,
    DayOfYear int NULL
)
GO
 
DROP TABLE IF EXISTS dbo.dim_time
GO

CREATE TABLE dbo.dim_time(
    [TimeKey] [int] IDENTITY(1,1) NOT NULL,
    [Time] [time](0) NULL,
    [Hour] [int] NULL,
    [Minute] [int] NULL,
    [MilitaryHour] int NOT null,
    [MilitaryMinute] int NOT null,
    [AMPM] [varchar](2) NOT NULL,
    [DayPartEN] [varchar](10) NULL,
    [DayPartNL] [varchar](10) NULL,
    [HourFromTo12] [varchar](17) NULL,
    [HourFromTo24] [varchar](13) NULL,
    [Notation12] [varchar](10) NULL,
    [Notation24] [varchar](10) NULL
)
GO
 
 
/******************************************************
* 4. Create fact table
*******************************************************/
DROP TABLE IF EXISTS dbo.fact_nmi_usage
GO

CREATE TABLE dbo.fact_nmi_usage(
	FactNmiUsageKey int IDENTITY(1,1) NOT NULL,
	DateKey int NOT NULL,
	TimeKey int NOT NULL,
	NmiKey int NOT NULL,
	Quantity_kWh decimal(38, 8) NULL,
	Total_Usage_kWh decimal(38, 8) NULL,  -- Sum(Quantity) of each Nmi on that date
	Usage_Rate decimal(38, 8) NULL,       -- the % of the usage on this time on that date
	Load_Timestamp datetime NOT NULL,
)
GO