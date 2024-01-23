
ALTER PROCEDURE dbo.RestoreTlogFile
@Path Varchar(1000) = '',		-- T-LOG BACKUP FOLDER PATH 
@DEL_RESTORED_FILE BIT = FALSE	-- TRUE/FALSE

AS

/*
Author: Riknu Kumar Singh
Created date: 24-Jan-2024
Ver: 1.0

EXEC RestoreTlogFile @Path = 'C:\Script\latest T-Log from folder\t_Backup', @DEL_RESTORED_FILE = FALSE

*/

BEGIN
    SET NOCOUNT ON;
	IF @Path = '' 
	BEGIN
	SELECT '** ENTER VALID PATH FOR LOG BACKUPS..!  **'
	END
	ELSE
	BEGIN

    DECLARE @cmd NVARCHAR(1000);
	DECLARE @backupPath NVARCHAR(500)

	SELECT @BackupPath = 'dir /ad /b "'+@Path+'"'

	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ListOfFolders')
	BEGIN
		CREATE TABLE ListOfFolders (ID INT IDENTITY(1,1), FOLDERNAME NVARCHAR(100))
	END

	TRUNCATE TABLE ListOfFolders;
	INSERT INTO ListOfFolders (FOLDERNAME) EXEC MASTER..xp_cmdshell @BackupPath;
	DELETE FROM ListOfFolders WHERE FOLDERNAME IS NULL

	DECLARE @MIN_ID INT = 1
	DECLARE @MAX_ID INT
	DECLARE @DBNAME VARCHAR(50) = ''
	SELECT @MAX_ID = MAX(ID) FROM ListOfFolders;
	WHILE @MIN_ID <= @MAX_ID
	BEGIN

    DECLARE @logFolder NVARCHAR(1000) = ''
	SELECT @DBNAME =  FOLDERNAME FROM ListOfFolders WHERE ID = @MIN_ID
	SELECT @logFolder = @Path + '\' + @DBNAME; 
	
	PRINT @logFolder
    -- Create a dynamic SQL command to get the most recent log file
    SET @cmd = NULL
	SET @cmd = 'dir /a-d /o-n /b "'+''+@logFolder+'\"*.TRN';

    -- Create a temporary table to store the result of the DIR command
	DROP TABLE IF EXISTS #LogFileList
    CREATE TABLE #LogFileList (ID INT IDENTITY(1,1), LogFileName NVARCHAR(1000));

    -- Insert the result of the DIR command into the temporary table
    INSERT INTO #LogFileList (LogFileName)
    EXEC xp_cmdshell @cmd;
	DELETE FROM #LogFileList WHERE LogFileName IS NULL OR LogFileName = 'File Not Found';

	--SELECT COUNT(*) FROM #LogFileList
	IF EXISTS (SELECT COUNT(*) FROM #LogFileList)
	BEGIN
	DROP TABLE IF EXISTS #LogFileList_TMP
	CREATE TABLE #LogFileList_TMP (ID INT IDENTITY(1,1), LogFileName NVARCHAR(1000), STATUS BIT DEFAULT 0);
	INSERT INTO #LogFileList_TMP (LogFileName) SELECT (LogFileName) FROM #LogFileList ORDER BY ID DESC

    -- Declare a variable to store the most recent log file
    DECLARE @LogFileNAME NVARCHAR(1000);
	DECLARE @STATUS BIT;
	DECLARE @DelCmd VARCHAR(2000);
	DECLARE @RESTORE NVARCHAR(2000) = ''
	DECLARE @MIN INT = 1
	DECLARE @MAX INT

	SELECT @MAX = MAX(ID) FROM #LogFileList_TMP;
	WHILE @MIN <= @MAX
	BEGIN

	SELECT @LogFileNAME = LOGFILENAME FROM #LogFileList_TMP WHERE ID = @MIN
	SELECT @STATUS = STATUS FROM #LogFileList_TMP WHERE ID = @MIN

	IF @STATUS = 0
	BEGIN
	SET @RESTORE = 'RESTORE LOG '+@DBNAME+' FROM DISK = '''+@logFolder+'\'+@LogFileNAME+''' WITH NORECOVERY';
	EXEC (@RESTORE);
	END
	
	IF @DEL_RESTORED_FILE = 'TRUE'
	BEGIN
	SET @DelCmd = 'DEL ' + QUOTENAME(@logFolder+'\'+@LogFileNAME, '"''');
	--print (@DelCmd)
	EXEC xp_cmdshell @DelCmd
	END

	SELECT @MIN = @MIN + 1
	END
	END
	SELECT @MIN_ID = @MIN_ID + 1
	END
END
END