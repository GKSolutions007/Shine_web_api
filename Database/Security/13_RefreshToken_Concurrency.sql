/* =====================================================================================
   13_RefreshToken_Concurrency.sql  -  Thread-safe / concurrency-safe JWT token rotation
   -------------------------------------------------------------------------------------
   Run on each Shine database after 05 (which adds AuthTokenHash / TokenHash). Safe to
   re-run (every step is guarded).

   WHY THE FIRST ATTEMPT WAS NOT ENOUGH
   ------------------------------------
   Production data showed two tblRefreshTokens rows with the SAME AuthToken (and the same
   AuthTokenHash), created ~200 ms apart. Root causes:

   1. The issued JWT had NO unique claim. GenerateToken built a jti GUID but never attached
      it to the token, so every token minted in the same WHOLE SECOND was byte-identical.
      -> Fixed in C# (TokenHelper): the jti/sub claims are now attached, so every AuthToken
         is unique. (This script does not depend on that, but the index choice below does.)
   2. Concurrency control was keyed on AuthTokenHash, which (a) was not unique and (b) would
      have produced FALSE collisions between unrelated logins in the same second.
      -> This script keys rotation on the row's primary key Id (a unique GUID) and keys the
         "one active row" uniqueness on SessionID, which is stable for the life of a session.

   WHAT THIS SCRIPT ADDS / CHANGES
     1. uspUpdateRefreshToken  - unchanged contract; now revokes ONLY a still-active row
        (IsRevoked = 1) under UPDLOCK/ROWLOCK and returns the row count actually changed.
     2. uspRotateRefreshToken  - rewritten to take @OldRowId (the primary key the API already
        validated) instead of the old AuthToken. One SERIALIZABLE transaction: claim the old
        row by Id only if still active, and only the winner inserts the single new active row.
     3. UX_p1_tblRefreshTokens_ActiveSession - filtered UNIQUE index: at most one ACTIVE
        (IsRevoked = 1) row per session. A safety net the DB enforces even if app logic slips.
        SessionID is a (MAX)/LOB column and cannot be an index key, so (as 05 already does for
        AuthToken/Token) a PERSISTED SHA-256 hash column SessionKeyHash is added and the index is
        built on that. A filtered index may not reference a computed column in its WHERE clause,
        so SessionKeyHash is built to be non-null and UNIQUE-per-row for sessionless rows (it
        hashes the row's own Id when SessionID is empty/NULL); the index then filters on the real
        IsRevoked column alone. Sessionless/legacy rows therefore never collide with each other.

   NOTE on the old index: if 13 was run previously it may have created
   UX_p1_tblRefreshTokens_ActiveAuth on AuthTokenHash. That index is DROPPED here because the
   AuthToken is not a safe uniqueness key (see cause #1).

   Rollback: DROP the two procedures and recreate the 05 version of uspUpdateRefreshToken;
   DROP INDEX UX_p1_tblRefreshTokens_ActiveSession ON dbo.tblRefreshTokens;
   ALTER TABLE dbo.tblRefreshTokens DROP COLUMN SessionKeyHash.
   ===================================================================================== */
-- These SET options must be ON/OFF as below both to create the PERSISTED computed column that
-- uses HASHBYTES and to create a FILTERED index. (Same set 05_Indexes.sql uses.)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
GO

/* ---------- 0. drop earlier artifacts from previous versions of this script ---------- */
-- 0a. the first version indexed AuthTokenHash (not a safe uniqueness key).
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_p1_tblRefreshTokens_ActiveAuth')
BEGIN
    DROP INDEX UX_p1_tblRefreshTokens_ActiveAuth ON dbo.tblRefreshTokens;
    PRINT N'dropped UX_p1_tblRefreshTokens_ActiveAuth (AuthTokenHash is not a safe uniqueness key)';
END
GO
-- 0b. the previous version added a nullable SessionIDHash that could not back a filtered index.
--     Drop any index on it first, then the column, so this re-run leaves a clean schema.
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_p1_tblRefreshTokens_ActiveSession')
   AND EXISTS (SELECT 1 FROM sys.index_columns ic
               JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
               JOIN sys.indexes i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
               WHERE i.name = N'UX_p1_tblRefreshTokens_ActiveSession' AND c.name = N'SessionIDHash')
BEGIN
    DROP INDEX UX_p1_tblRefreshTokens_ActiveSession ON dbo.tblRefreshTokens;
    PRINT N'dropped old UX_p1_tblRefreshTokens_ActiveSession (was keyed on SessionIDHash)';
END
GO
IF COL_LENGTH(N'dbo.tblRefreshTokens', N'SessionIDHash') IS NOT NULL
BEGIN
    ALTER TABLE dbo.tblRefreshTokens DROP COLUMN SessionIDHash;
    PRINT N'dropped orphaned computed column SessionIDHash';
END
GO

/* ---------- 1. de-duplicate existing duplicate ACTIVE rows per session ----------
   Before a unique index can be created there must be at most one active row per SessionID.
   Keep the newest (CreatedAt, then Id) and revoke the rest. Only touches current duplicates;
   a single active row per session is left alone. Rows with no SessionID are not touched. */
IF COL_LENGTH(N'dbo.tblRefreshTokens', N'SessionID') IS NOT NULL
BEGIN
    -- Partition by a fixed-length hash of the normalized SessionID (same key the unique index
    -- below uses). Grouping directly by the (MAX) column is not reliable; hashing makes it a
    -- comparable binary(32). Only ACTIVE rows with a real SessionID are considered.
    ;WITH dup AS (
        SELECT Id,
               ROW_NUMBER() OVER (
                   PARTITION BY CAST(HASHBYTES('SHA2_256', CAST(SessionID AS nvarchar(max))) AS binary(32))
                   ORDER BY CreatedAt DESC, Id DESC) AS rn
        FROM dbo.tblRefreshTokens
        WHERE IsRevoked = 1
          AND SessionID IS NOT NULL
          AND LTRIM(RTRIM(SessionID)) <> N''
    )
    UPDATE t SET t.IsRevoked = 0
    FROM dbo.tblRefreshTokens t
    JOIN dup ON dup.Id = t.Id
    WHERE dup.rn > 1;

    PRINT N'de-duplicated active refresh-token rows: ' + CAST(@@ROWCOUNT AS nvarchar(10));
END
GO

/* ---------- 2. filtered unique index: at most one ACTIVE row per SessionID ----------
   SessionID is stored as a (MAX)/LOB type, which SQL Server cannot use as an index key
   column. We follow the SAME pattern 05_Indexes.sql already uses for AuthToken/Token: add a
   PERSISTED SHA-256 hash column (fixed binary(32), fully indexable) and build the unique index
   on that. The base SessionID column is untouched, so existing data, the insert proc and any
   other reader keep working unchanged.

   Uniqueness is enforced only for ACTIVE rows that actually have a SessionID: the filter
   excludes revoked rows and rows whose SessionID is NULL or empty (legacy / missing session
   cookie), so those never collide with each other. */
IF COL_LENGTH(N'dbo.tblRefreshTokens', N'SessionID') IS NOT NULL
BEGIN
    -- 2a. persisted hash key for the unique index.
    --
    --   A filtered index's WHERE clause may NOT reference a computed column, so we cannot
    --   filter on "SessionIDHash IS NOT NULL". Instead the hash is built to NEVER be null and
    --   to be unique for rows that have no real session:
    --     * real SessionID  -> hash of the normalized SessionID (so all active rows of one
    --                          session share a key and collapse to a single active row);
    --     * empty / NULL     -> hash of the row's own Id (a unique GUID), so every legacy /
    --                          sessionless row gets a DISTINCT key and never collides with
    --                          another sessionless row.
    --   The index can then filter on IsRevoked alone, which is a real (non-computed) column.
    IF COL_LENGTH(N'dbo.tblRefreshTokens', N'SessionKeyHash') IS NULL
    BEGIN
        ALTER TABLE dbo.tblRefreshTokens
            ADD SessionKeyHash AS (
                CASE
                    WHEN SessionID IS NULL OR LTRIM(RTRIM(SessionID)) = N''
                        THEN CAST(HASHBYTES('SHA2_256', CAST(Id AS nvarchar(100))) AS binary(32))
                    ELSE CAST(HASHBYTES('SHA2_256', CAST(SessionID AS nvarchar(max))) AS binary(32))
                END
            ) PERSISTED;
        PRINT N'added computed column SessionKeyHash';
    END
END
GO

IF COL_LENGTH(N'dbo.tblRefreshTokens', N'SessionKeyHash') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_p1_tblRefreshTokens_ActiveSession')
BEGIN
    -- At most one ACTIVE row per session. The filter uses only IsRevoked (a base column);
    -- sessionless rows hash on their unique Id above, so they never collide with each other.
    CREATE UNIQUE INDEX UX_p1_tblRefreshTokens_ActiveSession
        ON dbo.tblRefreshTokens (SessionKeyHash)
        WHERE IsRevoked = 1;
    PRINT N'created UX_p1_tblRefreshTokens_ActiveSession';
END
GO

/* ---------- 3. uspUpdateRefreshToken: revoke only an active row, report rowcount ----------
   Same parameters as before (@TokenType, @Token). The UPDATE matches only rows that are still
   active (IsRevoked = 1), under UPDLOCK/ROWLOCK, and returns a single-row [RowsAffected] result
   set so existing SqlDataAdapter.Fill callers keep working and new callers can read the count. */
CREATE OR ALTER PROCEDURE [dbo].[uspUpdateRefreshToken]
    @TokenType int,
    @Token VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @h binary(32) = CAST(HASHBYTES('SHA2_256', CAST(@Token AS nvarchar(max))) AS binary(32));
    DECLARE @rows int = 0;

    IF (@TokenType = 1)
    BEGIN
        UPDATE dbo.tblRefreshTokens WITH (UPDLOCK, ROWLOCK)
        SET IsRevoked = 0
        WHERE TokenHash = @h AND Token = @Token AND IsRevoked = 1;
        SET @rows = @@ROWCOUNT;
    END
    ELSE
    BEGIN
        UPDATE dbo.tblRefreshTokens WITH (UPDLOCK, ROWLOCK)
        SET IsRevoked = 0
        WHERE AuthTokenHash = @h AND AuthToken = @Token AND IsRevoked = 1;
        SET @rows = @@ROWCOUNT;
    END

    SELECT @rows AS RowsAffected;
END
GO

/* ---------- 4. uspRotateRefreshToken: atomic claim-old-by-Id + insert-new ----------
   The application generates the new auth token (JWT) and new refresh token BEFORE calling
   this and passes them in, together with @OldRowId = the primary key of the row it validated.
   In one SERIALIZABLE transaction:
     a) revoke the old row BY Id, only if it is still active (IsRevoked = 1), under UPDLOCK;
     b) if exactly one row was claimed (this request won) insert one new active row, @Won = 1;
     c) if zero rows were claimed (another request already rotated) insert nothing, @Won = 0.
   The filtered unique index on SessionID is the final backstop: if two requests somehow both
   believed they won, the second INSERT violates the index and that transaction aborts rather
   than creating a duplicate active row. */
CREATE OR ALTER PROCEDURE [dbo].[uspRotateRefreshToken]
    @OldRowId           UNIQUEIDENTIFIER,
    @UserId             NVARCHAR(100),
    @NewRefreshToken    VARCHAR(MAX),
    @NewRefreshExpires  DATETIME,
    @SessionID          NVARCHAR(200),
    @NewAuthToken       VARCHAR(MAX),
    @NewAuthExpires     DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @won bit = 0;

    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- (a) Claim the exact row by its primary key. Only one concurrent request flips 1 -> 0.
        UPDATE dbo.tblRefreshTokens WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        SET IsRevoked = 0
        WHERE Id = @OldRowId
          AND IsRevoked = 1;

        IF (@@ROWCOUNT = 1)
        BEGIN
            -- (b) Winner inserts the new active session row.
            INSERT INTO dbo.tblRefreshTokens
                (UserId, Token, ExpiresAt, IsRevoked, SessionID, AuthToken, AuthTokenExpireAt)
            VALUES
                (@UserId, @NewRefreshToken, @NewRefreshExpires, 1, @SessionID, @NewAuthToken, @NewAuthExpires);
            SET @won = 1;
        END
        -- (c) Loser: @won stays 0, nothing inserted.

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0) ROLLBACK TRANSACTION;

        -- Unique-index violation (2601/2627) means another request already created the active
        -- row for this session: treat as "did not win", not as an error.
        IF (ERROR_NUMBER() IN (2601, 2627))
            SET @won = 0;
        ELSE
            THROW;
    END CATCH

    SELECT @won AS Won;
END
GO

PRINT N'13_RefreshToken_Concurrency.sql complete.';
GO
