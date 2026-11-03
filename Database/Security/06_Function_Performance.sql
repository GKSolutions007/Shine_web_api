/* =====================================================================================
   06_Function_Performance.sql  -  P1: fnSplitString / fnGetRoundedValue
   -------------------------------------------------------------------------------------
   Run on each Shine database (compatibility level 130 or higher; Shine DBs are 160). Safe to re-run.

   fnSplitString (used about 210 times, always as  col IN (SELECT * FROM dbo.fnSplitString(@x, ',')) )
     Was a multi-statement function: a WHILE loop filling a table variable, which SQL Server
     cannot see into (fixed row estimate, executed separately for every call).
     Now an inline function over STRING_SPLIT, which the optimizer expands into the calling query.
     Same name, parameters and output column (id nvarchar(max)) and the same rows for every input
     (empty pieces, NULL string -> no rows, NULL separator -> no rows); verified against the old
     version on the test database.
   fnGetRoundedValue (used about 1,600 times)
     Already inlineable (sys.sql_modules.is_inlineable = 1) and SQL Server 2019+ inlines it on
     these databases, so the per-row read of tblAppConfig no longer happens. Not changed.

   Rollback: re-create the previous fnSplitString from the script.ipynb export (DROP + CREATE).
   ===================================================================================== */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF (SELECT compatibility_level FROM sys.databases WHERE database_id = DB_ID()) < 130
    THROW 50001, N'STRING_SPLIT needs database compatibility level 130 or higher.', 1;
IF EXISTS (SELECT 1 FROM sys.sql_expression_dependencies d
           WHERE d.referenced_id = OBJECT_ID(N'dbo.fnSplitString') AND d.is_schema_bound_reference = 1)
    THROW 50002, N'A schema-bound object references dbo.fnSplitString; change it first.', 1;
GO
IF OBJECT_ID(N'dbo.fnSplitString') IS NOT NULL AND OBJECTPROPERTY(OBJECT_ID(N'dbo.fnSplitString'), 'IsInlineFunction') = 0
    DROP FUNCTION dbo.fnSplitString;
GO
--select * from [fnSplitString]('15,45,65',',')
CREATE OR ALTER FUNCTION [dbo].[fnSplitString]
(@string NVARCHAR(MAX),@strSeparator NCHAR(1))
RETURNS TABLE
AS
RETURN
    SELECT CAST(s.value AS nvarchar(max)) AS id
    FROM STRING_SPLIT(@string, ISNULL(@strSeparator, N',')) AS s
    WHERE @strSeparator IS NOT NULL;   -- the old function returned no rows for a NULL separator
GO
