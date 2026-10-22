/*
Purpose: Create the HomeCreditBI database when it does not already exist.
Safety: This script never drops or overwrites an existing database.
*/

USE master;
GO

IF DB_ID(N'HomeCreditBI') IS NULL
BEGIN
    CREATE DATABASE HomeCreditBI;
END;
GO

USE HomeCreditBI;
GO
