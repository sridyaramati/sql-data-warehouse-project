/*
==============================================================================

Quality Checks

==============================================================================

Script Purpose: 
	This script performs various quality checks for data consistency, accuracy,
	and standardization across the 'silver' schema. It includes checks for:
	- Null or duplicate primary keys
	- Unwanted spaces in string fields
	- Data standardization and consistency
	- Invalid date ranges and orders
	- Data consistency between related fields

Usage Notes:
	- Run these checks after data loading Silver layer
	- Investigate and resolve any discrepancies found during the checks.
==================================================================================
*/


-- ===============================================================================
-- Checking for 'silver.crm_cust_info'
-- ===============================================================================
-- Check for Nulls or duplicates in Primary Key
-- Expectation: No result

SELECT 
cst_id,
COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Checking for unwanted spaces
SELECT cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

SELECT cst_gndr
FROM silver.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr);

--Data Standardization and consistency
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;

SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info;


-- ===============================================================================
-- Checking for 'silver.crm_prd_info'
-- ===============================================================================
-- Check for Nulls or duplicates in Primary Key
SELECT 
prd_id,
COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;


-- Checking for unwanted spaces
SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- checking for NULLs or negative numbers
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data Standardization and Consistency
SELECT DISTINCT prd_line FROM silver.crm_prd_info;

-- check for invalid date orders
SELECT
*
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- adjust the start and end dates for the products as they are jumbled and not following any order

SELECT
prd_id,
prd_key,
prd_name,
prd_start_dt,
prd_end_dt,
DATEADD(day, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)) AS prd_end_dt_test 
FROM bronze.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509');

SELECT
*
FROM silver.crm_prd_info;



-- ===============================================================================
-- Checking for 'silver.crm_sales_details'
-- ===============================================================================
SELECT
*
FROM bronze.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num);

SELECT
*
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)

SELECT
*
FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info)

-- check invalid dates

SELECT
NULLIF(sls_order_dt,0) AS sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <=0 
OR LEN(sls_order_dt) != 8 
OR sls_order_dt > 20500101
OR sls_order_dt < 19000101

SELECT
NULLIF(sls_ship_dt,0) AS sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt <=0 
OR LEN(sls_ship_dt) != 8 
OR sls_ship_dt > 20500101
OR sls_ship_dt < 19000101

SELECT
NULLIF(sls_due_dt,0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <=0 
OR LEN(sls_due_dt) != 8 
OR sls_due_dt > 20500101
OR sls_due_dt < 19000101

-- check for invalid date orders

SELECT
*
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

-- check data inconsistency: between sales, quantity, and price
-- sales = quantity * price
-- values must not be NULL or zero or negative

SELECT DISTINCT
sls_sales,
sls_quantity,
sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price  
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- Rules to fix above issues: 1. if sales is -ve, 0 or null, derive it using quantity * price
-- 2. if price is null or 0, calculate by sales/quantity
-- 3. if price is negative, convert it to a positive value

SELECT DISTINCT
sls_sales as old_sales,
sls_quantity,
sls_price as old_sls_price,

CASE WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price)
	THEN sls_quantity * ABS(sls_price)
	ELSE sls_sales
END AS sls_sales,

CASE WHEN sls_price IS NULL OR sls_price <=0
	THEN sls_sales / NULLIF(sls_quantity,0)
ELSE sls_price
END AS sls_price
FROM bronze.crm_sales_details;

SELECT * FROM silver.crm_sales_details

-- ERP tables

-- ===============================================================================
-- Checking for 'silver.erp_cust_az12'
-- ===============================================================================
-- cid has extra chars which is difficult to connect with crm_cust_info table
SELECT
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
	ELSE cid
END cid,
bdate,
gen
FROM bronze.erp_cust_az12;

-- identify out of range dates

SELECT DISTINCT
bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();

-- data standardization & consistency

SELECT DISTINCT gen,
CASE WHEN UPPER(TRIM(gen)) IN ('F', 'Female') THEN 'Female'
	 WHEN UPPER(TRIM(gen)) IN ('M', 'Male') THEN 'Male'
	 ELSE 'n/a'
END AS gen
FROM silver.erp_cust_az12;

SELECT * FROM silver.erp_cust_az12;

-- ===============================================================================
-- Checking for 'silver.erp_loc_a101'
-- ===============================================================================
-- to join this table with crm_cust_info, cid has extra char of '-', need to remove for consistency

SELECT
REPLACE(cid, '-', '') AS cid,
cntry
FROM bronze.erp_loc_a101
--WHERE REPLACE(cid, '-', '') NOT IN (SELECT cst_key FROM silver.crm_cust_info)
;

-- data standardization & consistency
SELECT DISTINCT cntry, cid
FROM silver.erp_loc_a101
ORDER BY cntry;

SELECT DISTINCT
CASE 
	WHEN TRIM(cntry) = 'DE' THEN 'Germany'
	WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
	WHEN TRIM(cntry)  IN('US', 'USA') THEN 'United States'
	ELSE TRIM(cntry)
END AS cntry
FROM bronze.erp_loc_a101;

-- ===============================================================================
-- Checking for 'silver.erp_px_cat_g1v2'
-- ===============================================================================
SELECT 
id,
cat,
subcat,
maintenance
FROM bronze.erp_px_cat_g1v2;

-- checking unwanted spaces

SELECT * FROM bronze.erp_px_cat_g1v2
WHERE cat!= TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance)

-- data standardization & consistency

SELECT DISTINCT
cat
FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT
subcat
FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT
maintenance
FROM bronze.erp_px_cat_g1v2;

SELECT *
FROM silver.erp_px_cat_g1v2;
