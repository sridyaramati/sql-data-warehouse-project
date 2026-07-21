/*
===============================
Create Database and Schemas
===============================
Script Purpose:
This script creates a new database named 'DataWarehouse' after checking if it already exists.
If the database already exists, it is dropped and recreated. Additionally, the script sets up three scehmas within the database: bronze, silver, gold.

Warning: 
Running this script will drop the entire 'DataWarehouse' database if it exists. All data in the database will be deleted permanently. 
*/



USE master;

-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name ='DataWarehouse')
BEGIN
	ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE DataWarehouse;
END;
GO

-- Create the 'DataWarehouse' database
CREATE DATABASE DataWarehouse;

USE DataWarehouse;

-- Create Schemas

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
