/* =====================================================================================
   09_NoCount_XactAbort.sql  -  P2: SET NOCOUNT ON / SET XACT_ABORT ON in stored procedures
   -------------------------------------------------------------------------------------
   Run on each Shine database AFTER 01-08 and after the API/UI build that contains the
   SafeRollback change in DALHelper\clsDAL.cs. Safe to re-run (changed procedures carry the
   marker  /*p2:09*/  and are skipped the next time). Works on any version of the procedures:
   it edits whatever definition the database has, it does not ship procedure text.

   What it does, per dbo procedure:
   1. SET NOCOUNT ON is added as the first statement of every procedure.
      Stops the "n rows affected" message after every statement (one network message each).
      Result sets, @@ROWCOUNT and OUTPUT parameters do not change. The API never reads the
      rows-affected count (no ExecuteNonQuery return value is used).
   2. SET XACT_ABORT ON is added too, except where it would change how errors are reported:
      - the procedure has BEGIN TRY/CATCH, or calls (directly or via other procedures, also by
        name inside dynamic SQL) a procedure that has it, or is called by one.
        Reason: most of these CATCH blocks return the error as a result row
        (SELECT ERROR_MESSAGE() ...) and the API reads that row. With XACT_ABORT ON the open
        transaction would be doomed inside CATCH, and the call would end in an exception
        instead of the row the screens expect.
      For every other procedure an error already reaches the API as an exception today;
      XACT_ABORT ON only makes sure the work done before the error is rolled back and nothing
      after the error runs (no half-posted document if the procedure opens its own transaction,
      and a command timeout no longer leaves a transaction open).
   3. Writer procedures that the API calls WITHOUT a transaction and whose CATCH returns an error
      row (masters: customer, vendor, product, accounts, document series, ...) get a guarded
      transaction, so a failure half way no longer leaves half the rows written:
         BEGIN TRY  -> DECLARE @p2_tc int = @@TRANCOUNT; IF @p2_tc = 0 BEGIN TRANSACTION;
         END TRY    <- IF @p2_tc = 0 AND @@TRANCOUNT > 0 COMMIT TRANSACTION;
         BEGIN CATCH-> IF @p2_tc = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
      If the caller already has a transaction (@p2_tc > 0) nothing changes. Only done when the
      procedure has exactly one TRY/CATCH, no RETURN and no transaction statements of its own;
      otherwise it is listed as "wrap skipped".
   4. Same idea for writer procedures WITHOUT TRY/CATCH that the API calls without a transaction
      and that write several times (list @WrapNoTry: role menus delete + insert, the 50+ settings
      rows of the app config screen, mappings, ...): XACT_ABORT alone does not help them, because
      without a transaction every statement commits on its own. They get
         after AS   -> DECLARE @p2_tc int = @@TRANCOUNT; IF @p2_tc = 0 BEGIN TRANSACTION;
         last line  <- IF @p2_tc = 0 AND @@TRANCOUNT > 0 COMMIT TRANSACTION;
      and XACT_ABORT ON, so an error rolls the whole call back. Only when the procedure gets
      XACT_ABORT ON and has no RETURN/GOTO/transaction statements.

   Not changed: certificate-signed procedures (ALTER would remove the signature, see 03),
   encrypted procedures, and the procedures called only by the mobile backend that write data
   (list @External below: that code is not in this repository and may read rows-affected).

   ANSI_NULLS / QUOTED_IDENTIFIER of every procedure are kept as they were.
   Every old definition is saved in dbo.DbaProcBackup before it is changed.
   Rollback of one procedure:
       DECLARE @d nvarchar(max) = (SELECT TOP 1 Definition FROM dbo.DbaProcBackup
                                   WHERE ProcName = N'<name>' AND Script = '09' ORDER BY BackupID DESC);
       -- replace the leading CREATE by ALTER in @d, then EXEC sys.sp_executesql @d;
   Set @Apply = 0 below to only report what would change.
   ===================================================================================== */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.DbaProcBackup', N'U') IS NULL
    CREATE TABLE dbo.DbaProcBackup (
        BackupID int IDENTITY(1,1) CONSTRAINT PK_DbaProcBackup PRIMARY KEY,
        ProcName sysname NOT NULL,
        Script varchar(10) NOT NULL,
        SavedAt datetime2(0) NOT NULL CONSTRAINT DF_DbaProcBackup_SavedAt DEFAULT SYSDATETIME(),
        UsesAnsiNulls bit NULL,
        UsesQuotedIdentifier bit NULL,
        Definition nvarchar(max) NOT NULL);
GO
IF OBJECT_ID(N'tempdb..#p2_Tokens') IS NOT NULL DROP PROCEDURE #p2_Tokens;
GO
/* Lists the word tokens of a T-SQL module that are outside comments, string literals and
   [ ] / " " quoted names, with their position and parenthesis depth.
   @HeaderOnly = 1 stops at the AS that ends the CREATE PROCEDURE header. */
CREATE PROCEDURE #p2_Tokens @def nvarchar(max), @HeaderOnly bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @t TABLE (seq int IDENTITY PRIMARY KEY, pos int, len_ int, tok nvarchar(128), depth int, prev nvarchar(128));
    DECLARE @n int = LEN(@def + N'x') - 1, @i int = 1, @j int, @lvl int, @c nchar(1), @c2 nchar(2),
            @depth int = 0, @prev nvarchar(128) = N'', @tok nvarchar(128), @stage int = 0, @done bit = 0;
    WHILE @i <= @n AND @done = 0
    BEGIN
        SET @c = SUBSTRING(@def, @i, 1);
        SET @c2 = SUBSTRING(@def, @i, 2);
        IF @c2 = N'--'
        BEGIN
            SET @j = CHARINDEX(NCHAR(10), @def, @i);
            SET @i = CASE WHEN @j = 0 THEN @n + 1 ELSE @j + 1 END;
            CONTINUE;
        END
        IF @c2 = N'/*'
        BEGIN
            SET @lvl = 1; SET @i += 2;
            WHILE @i <= @n AND @lvl > 0
            BEGIN
                SET @c2 = SUBSTRING(@def, @i, 2);
                IF @c2 = N'/*' BEGIN SET @lvl += 1; SET @i += 2; END
                ELSE IF @c2 = N'*/' BEGIN SET @lvl -= 1; SET @i += 2; END
                ELSE BEGIN
                    -- jump to the next * or / (comments can be long)
                    SET @j = PATINDEX(N'%[*/]%', SUBSTRING(@def, @i + 1, 4000));
                    SET @i += CASE WHEN @j = 0 THEN 4000 ELSE @j END;
                END
            END
            CONTINUE;
        END
        IF @c = N''''
        BEGIN
            SET @i += 1;
            WHILE @i <= @n
            BEGIN
                SET @j = CHARINDEX(N'''', @def, @i);
                IF @j = 0 BEGIN SET @i = @n + 1; BREAK; END
                IF SUBSTRING(@def, @j + 1, 1) = N'''' SET @i = @j + 2;
                ELSE BEGIN SET @i = @j + 1; BREAK; END
            END
            SET @prev = N'''';
            CONTINUE;
        END
        IF @c IN (N'[', N'"')
        BEGIN
            SET @j = CHARINDEX(CASE @c WHEN N'[' THEN N']' ELSE N'"' END, @def, @i + 1);
            SET @i = CASE WHEN @j = 0 THEN @n + 1 ELSE @j + 1 END;
            SET @prev = N'[name]';
            CONTINUE;
        END
        IF @c = N'(' BEGIN SET @depth += 1; SET @prev = N'('; SET @i += 1; CONTINUE; END
        IF @c = N')' BEGIN SET @depth -= 1; SET @prev = N')'; SET @i += 1; CONTINUE; END
        IF @c LIKE N'[A-Za-z0-9_@#$]'
        BEGIN
            SET @j = @i + 1;
            WHILE @j <= @n AND SUBSTRING(@def, @j, 1) LIKE N'[A-Za-z0-9_@#$]' SET @j += 1;
            SET @tok = UPPER(SUBSTRING(@def, @i, @j - @i));
            INSERT @t (pos, len_, tok, depth, prev) VALUES (@i, @j - @i, @tok, @depth, @prev);
            IF @HeaderOnly = 1
            BEGIN
                IF @stage = 0 AND @tok = N'CREATE' SET @stage = 1;
                ELSE IF @stage = 1 AND @tok IN (N'PROC', N'PROCEDURE') SET @stage = 2;
                ELSE IF @stage = 2 AND @depth = 0 AND @tok = N'AS' AND LEFT(@prev, 1) <> N'@' AND @prev NOT IN (N'EXEC', N'EXECUTE')
                    SET @done = 1;
            END
            SET @prev = @tok;
            SET @i = @j;
            CONTINUE;
        END
        IF @c NOT IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13)) SET @prev = @c;
        SET @i += 1;
    END
    SELECT pos, len_, tok, depth, prev FROM @t ORDER BY seq;
END
GO

SET NOCOUNT ON;
DECLARE @Apply bit = 1;               -- 0 = only report
DECLARE @Marker nvarchar(20) = N'/*p2:09*/';

-- Called only by the mobile backend (not by this API/UI) and they write data: left unchanged.
DECLARE @External TABLE (name sysname PRIMARY KEY);
INSERT @External VALUES (N'TEMPVLSQTYADJ'), (N'uspgetsetMobileDraftInvoice'), (N'uspManageOrderReturnSave'), (N'uspManageTodayRoute'),
    (N'uspMobileDeviceSaveLoginInfo'), (N'uspSamplePrintDetailSave'), (N'uspSaveCustomerfromMobile'), (N'UspSaveGstReconciliation'),
    (N'uspSaveMobileDelivery'), (N'uspSaveMobileVLSData'), (N'UspSavePreferredLanguage'), (N'uspUpdateFAGroupLevels');

-- Writer procedures the API/UI call without a transaction (bl_ExecuteParamSP...), whose CATCH
-- returns an error row: these get the guarded transaction of step 3.
DECLARE @Wrap TABLE (name sysname PRIMARY KEY);
INSERT @Wrap VALUES (N'uspSaveDocumentSeries'), (N'uspManageVendorMaster'), (N'uspManageProductPricechangedata'),
    (N'uspManageProductMasterImport'), (N'uspManageProductMaster'), (N'uspManageFinancialAccountGroup'),
    (N'uspManageFinancialAccount'), (N'uspManageCustomerMasterImport'), (N'uspManageCustomerMaster'),
    (N'uspValidateWebCollection'), (N'uspGetSetBarcodeProfileConfig');

-- Writer procedures WITHOUT TRY/CATCH that the API/UI call without a transaction and that write
-- more than once (delete + insert, many settings rows, ...). XACT_ABORT alone does not help them:
-- without a transaction every statement commits on its own. They get a guarded transaction for the
-- whole procedure (only when they also get XACT_ABORT ON, so an error rolls everything back).
DECLARE @WrapNoTry TABLE (name sysname PRIMARY KEY);
INSERT @WrapNoTry VALUES (N'uspSaveGendralColumnSettings'), (N'uspUpdateMapRoleMenus'), (N'uspManageApplicationConfig'),
    (N'uspManageColorSettings'), (N'uspManageBranchMapping'), (N'uspManageManufacturerMapping'), (N'uspManageMenuOrder'),
    (N'uspUpdateProductLocationMapping'), (N'uspImportBeatsalesmanMapping'), (N'uspImportCustomerRemarks'),
    (N'uspManagePrintProfileconfig'), (N'uspManageProductTransactionPrice'), (N'uspGetSetPrintConfig'),
    (N'uspManageDeviceApproval'), (N'uspValidateDevice'), (N'uspLoginInfoRecieve'), (N'uspVerifyMobileDeviceInfo'),
    (N'uspSaveImagedata'), (N'uspUpdateRefreshToken');

IF OBJECT_ID(N'tempdb..#p') IS NOT NULL DROP TABLE #p;
CREATE TABLE #p (
    object_id int PRIMARY KEY, name sysname NOT NULL, def nvarchar(max) NULL, norm nvarchar(max) NULL,
    ansi_nulls bit NULL, quoted_id bit NULL, signed bit NOT NULL DEFAULT 0,
    has_try bit NOT NULL DEFAULT 0, add_xact bit NOT NULL DEFAULT 0, wrap bit NOT NULL DEFAULT 0, wrap_nt bit NOT NULL DEFAULT 0,
    status varchar(30) NULL, note nvarchar(300) NULL, new_def nvarchar(max) NULL);

INSERT #p (object_id, name, def, ansi_nulls, quoted_id, signed)
SELECT p.object_id, p.name, m.definition, m.uses_ansi_nulls, m.uses_quoted_identifier,
       CASE WHEN EXISTS (SELECT 1 FROM sys.crypt_properties cp WHERE cp.class = 1 AND cp.major_id = p.object_id) THEN 1 ELSE 0 END
FROM sys.procedures p JOIN sys.sql_modules m ON m.object_id = p.object_id
WHERE p.schema_id = SCHEMA_ID(N'dbo') AND p.type = 'P' AND p.is_ms_shipped = 0;

-- whitespace-normalised upper-case copy for keyword checks (comments included: conservative)
UPDATE #p SET norm = UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(def, NCHAR(9), N' '), NCHAR(13), N' '), NCHAR(10), N' '),
                                   N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N''));
UPDATE #p SET has_try = CASE WHEN norm LIKE N'%BEGIN TRY%' THEN 1 ELSE 0 END;

UPDATE #p SET status = 'skipped', note = N'encrypted' WHERE def IS NULL;
UPDATE #p SET status = 'already done' WHERE status IS NULL AND def LIKE N'%' + @Marker + N'%';
UPDATE #p SET status = 'skipped', note = N'certificate-signed (see 03)' WHERE status IS NULL AND signed = 1;
UPDATE #p SET status = 'skipped', note = N'called only by the mobile backend and writes data'
WHERE status IS NULL AND name IN (SELECT name FROM @External);

-- call graph: catalog dependencies + procedure names mentioned in the text (dynamic SQL)
IF OBJECT_ID(N'tempdb..#e') IS NOT NULL DROP TABLE #e;
CREATE TABLE #e (caller int NOT NULL, callee int NOT NULL, PRIMARY KEY (caller, callee));
INSERT #e
SELECT DISTINCT d.referencing_id, q.object_id
FROM sys.sql_expression_dependencies d JOIN #p q ON q.name = d.referenced_entity_name
WHERE d.referencing_id IN (SELECT object_id FROM #p) AND d.referencing_id <> q.object_id;
INSERT #e
SELECT a.object_id, b.object_id FROM #p a JOIN #p b ON a.object_id <> b.object_id
WHERE a.def IS NOT NULL AND CHARINDEX(b.name, a.def) > 0
  AND a.def LIKE N'%[^A-Za-z0-9_]' + REPLACE(b.name, N'_', N'[_]') + N'[^A-Za-z0-9_]%'
  AND NOT EXISTS (SELECT 1 FROM #e x WHERE x.caller = a.object_id AND x.callee = b.object_id);

-- procedures that run while a TRY/CATCH is active above them, or above which one runs
IF OBJECT_ID(N'tempdb..#up') IS NOT NULL DROP TABLE #up;
IF OBJECT_ID(N'tempdb..#down') IS NOT NULL DROP TABLE #down;
CREATE TABLE #up (object_id int PRIMARY KEY);
CREATE TABLE #down (object_id int PRIMARY KEY);
INSERT #up SELECT object_id FROM #p WHERE has_try = 1;
INSERT #down SELECT object_id FROM #p WHERE has_try = 1;
DECLARE @added int = 1;
WHILE @added > 0
BEGIN
    INSERT #up SELECT DISTINCT e.caller FROM #e e JOIN #up u ON u.object_id = e.callee
    WHERE NOT EXISTS (SELECT 1 FROM #up x WHERE x.object_id = e.caller);
    SET @added = @@ROWCOUNT;
END
SET @added = 1;
WHILE @added > 0
BEGIN
    INSERT #down SELECT DISTINCT e.callee FROM #e e JOIN #down d ON d.object_id = e.caller
    WHERE NOT EXISTS (SELECT 1 FROM #down x WHERE x.object_id = e.callee);
    SET @added = @@ROWCOUNT;
END
UPDATE #p SET add_xact = CASE WHEN object_id IN (SELECT object_id FROM #up UNION SELECT object_id FROM #down) THEN 0 ELSE 1 END
WHERE status IS NULL;
UPDATE #p SET wrap = 1 WHERE status IS NULL AND name IN (SELECT name FROM @Wrap);
UPDATE #p SET wrap_nt = 1 WHERE status IS NULL AND has_try = 0 AND add_xact = 1 AND name IN (SELECT name FROM @WrapNoTry);

-- build the new definitions
IF OBJECT_ID(N'tempdb..#tok') IS NOT NULL DROP TABLE #tok;
CREATE TABLE #tok (seq int IDENTITY PRIMARY KEY, pos int, len_ int, tok nvarchar(128), depth int, prev nvarchar(128));
DECLARE @id int, @name sysname, @def nvarchar(max), @new nvarchar(max), @xact bit, @wrapIt bit,
        @asEnd int, @createPos int, @orAlter bit, @line nvarchar(200), @why nvarchar(300),
        @tryPos int, @endTryPos int, @catchPos int, @wrapNT bit, @ntDone bit;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT object_id, name, def, add_xact, wrap, wrap_nt FROM #p WHERE status IS NULL ORDER BY name;
OPEN c;
FETCH NEXT FROM c INTO @id, @name, @def, @xact, @wrapIt, @wrapNT;
WHILE @@FETCH_STATUS = 0
BEGIN
    TRUNCATE TABLE #tok;
    INSERT #tok (pos, len_, tok, depth, prev) EXEC #p2_Tokens @def, @HeaderOnly = 1;
    SELECT @createPos = MIN(pos) FROM #tok WHERE tok = N'CREATE';
    SELECT @asEnd = MAX(pos + len_ - 1) FROM (SELECT TOP 1 pos, len_ FROM #tok ORDER BY seq DESC) x WHERE EXISTS (SELECT 1 FROM #tok WHERE tok = N'AS');
    SET @orAlter = CASE WHEN EXISTS (SELECT 1 FROM #tok t WHERE t.tok = N'OR' AND t.seq = (SELECT MIN(seq) + 1 FROM #tok WHERE tok = N'CREATE')) THEN 1 ELSE 0 END;
    IF @createPos IS NULL OR @asEnd IS NULL OR (SELECT TOP 1 tok FROM #tok ORDER BY seq DESC) <> N'AS'
    BEGIN
        UPDATE #p SET status = 'skipped', note = N'could not find the procedure header' WHERE object_id = @id;
    END
    ELSE
    BEGIN
        SET @new = @def; SET @why = NULL;
        IF @wrapIt = 1
        BEGIN
            -- guarded transaction around the single TRY block (positions found outside comments/strings)
            TRUNCATE TABLE #tok;
            INSERT #tok (pos, len_, tok, depth, prev) EXEC #p2_Tokens @def, @HeaderOnly = 0;
            IF (SELECT COUNT(*) FROM #tok WHERE tok = N'TRY' AND prev = N'BEGIN') <> 1
               OR (SELECT COUNT(*) FROM #tok WHERE tok = N'TRY' AND prev = N'END') <> 1
               OR (SELECT COUNT(*) FROM #tok WHERE tok = N'CATCH' AND prev = N'BEGIN') <> 1
               OR EXISTS (SELECT 1 FROM #tok WHERE tok IN (N'RETURN', N'TRAN', N'TRANSACTION', N'COMMIT', N'ROLLBACK', N'SAVE', N'GOTO'))
                SET @why = N'wrap skipped: needs exactly one TRY/CATCH and no RETURN/GOTO/transaction statements';
            ELSE
            BEGIN
                SELECT @tryPos = pos + len_ FROM #tok WHERE tok = N'TRY' AND prev = N'BEGIN';
                SELECT @endTryPos = t.pos FROM #tok t WHERE t.tok = N'END' AND EXISTS (SELECT 1 FROM #tok u WHERE u.seq = t.seq + 1 AND u.tok = N'TRY' AND u.prev = N'END');
                SELECT @catchPos = pos + len_ FROM #tok WHERE tok = N'CATCH' AND prev = N'BEGIN';
                -- insert from the end backwards so earlier positions stay valid; no new lines are
                -- added, so ERROR_LINE() in the error rows the procedures return stays the same
                SET @new = STUFF(@new, @catchPos, 0, N' IF @p2_tc = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION; ' + @Marker + N' ');
                SET @new = STUFF(@new, @endTryPos, 0, N'IF @p2_tc = 0 AND @@TRANCOUNT > 0 COMMIT TRANSACTION; ' + @Marker + N' ');
                SET @new = STUFF(@new, @tryPos, 0, N' DECLARE @p2_tc int = @@TRANCOUNT; IF @p2_tc = 0 BEGIN TRANSACTION; ' + @Marker + N' ');
            END
        END
        SET @ntDone = 0;
        IF @wrapNT = 1
        BEGIN
            -- no TRY/CATCH: one transaction for the whole procedure; with XACT_ABORT ON an error
            -- rolls all of it back. Only without RETURN/GOTO/transaction statements of its own.
            TRUNCATE TABLE #tok;
            INSERT #tok (pos, len_, tok, depth, prev) EXEC #p2_Tokens @def, @HeaderOnly = 0;
            IF EXISTS (SELECT 1 FROM #tok WHERE tok IN (N'RETURN', N'TRAN', N'TRANSACTION', N'COMMIT', N'ROLLBACK', N'SAVE', N'GOTO', N'TRY'))
                SET @why = N'wrap skipped: RETURN/GOTO/transaction statements in the procedure';
            ELSE
            BEGIN
                -- appended on a new last line, so the line numbers above do not move
                SET @new = @new + NCHAR(13) + NCHAR(10) + N'IF @p2_tc = 0 AND @@TRANCOUNT > 0 COMMIT TRANSACTION; ' + @Marker;
                SET @ntDone = 1;
            END
        END
        SET @line = N'SET NOCOUNT ON; ' + CASE WHEN @xact = 1 THEN N'SET XACT_ABORT ON; ' ELSE N'' END
                  + CASE WHEN @ntDone = 1 THEN N'DECLARE @p2_tc int = @@TRANCOUNT; IF @p2_tc = 0 BEGIN TRANSACTION; ' ELSE N'' END
                  + @Marker + N' ';
        SET @new = STUFF(@new, @asEnd + 1, 0, N' ' + @line);
        IF @orAlter = 0 SET @new = STUFF(@new, @createPos, 6, N'ALTER');
        UPDATE #p SET new_def = @new, status = 'to change',
               note = CONCAT(CASE WHEN @xact = 1 THEN N'NOCOUNT + XACT_ABORT' ELSE N'NOCOUNT only (TRY/CATCH in call chain)' END,
                             CASE WHEN (@wrapIt = 1 AND @why IS NULL) OR @ntDone = 1 THEN N'; guarded transaction added' ELSE N'' END,
                             CASE WHEN @why IS NOT NULL THEN N'; ' + @why ELSE N'' END)
        WHERE object_id = @id;
    END
    FETCH NEXT FROM c INTO @id, @name, @def, @xact, @wrapIt, @wrapNT;
END
CLOSE c; DEALLOCATE c;

-- apply
DECLARE @an bit, @qi bit, @sql nvarchar(max), @err nvarchar(2048);
IF @Apply = 1
BEGIN
    DECLARE a CURSOR LOCAL FAST_FORWARD FOR SELECT object_id, name, def, new_def, ansi_nulls, quoted_id FROM #p WHERE status = 'to change' ORDER BY name;
    OPEN a;
    FETCH NEXT FROM a INTO @id, @name, @def, @new, @an, @qi;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            INSERT dbo.DbaProcBackup (ProcName, Script, UsesAnsiNulls, UsesQuotedIdentifier, Definition) VALUES (@name, '09', @an, @qi, @def);
            -- the inner batch is parsed with the procedure's own ANSI_NULLS / QUOTED_IDENTIFIER
            SET @sql = N'SET ANSI_NULLS ' + CASE WHEN @an = 1 THEN N'ON' ELSE N'OFF' END
                     + N'; SET QUOTED_IDENTIFIER ' + CASE WHEN @qi = 1 THEN N'ON' ELSE N'OFF' END
                     + N'; EXEC sys.sp_executesql @d;';
            EXEC sys.sp_executesql @sql, N'@d nvarchar(max)', @d = @new;
            UPDATE #p SET status = 'changed' WHERE object_id = @id;
        END TRY
        BEGIN CATCH
            SET @err = ERROR_MESSAGE();
            UPDATE #p SET status = 'FAILED', note = LEFT(@err, 300) WHERE object_id = @id;
        END CATCH
        FETCH NEXT FROM a INTO @id, @name, @def, @new, @an, @qi;
    END
    CLOSE a; DEALLOCATE a;
END

SELECT status, note, COUNT(*) AS procedures FROM #p GROUP BY status, note ORDER BY status, note;
SELECT name, status, note FROM #p WHERE status IN ('FAILED', 'skipped') OR note LIKE N'%wrap%' OR note LIKE N'%guarded%' ORDER BY status, name;
IF EXISTS (SELECT 1 FROM #p WHERE status = 'FAILED')
    THROW 50090, N'Some procedures could not be changed; see the list above (their old definition is unchanged).', 1;
GO
IF OBJECT_ID(N'tempdb..#p2_Tokens') IS NOT NULL DROP PROCEDURE #p2_Tokens;
GO
