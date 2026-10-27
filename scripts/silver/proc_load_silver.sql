/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
    Actions Performed:
        - Truncates Silver tables.
        - Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters:
    None.
      This stored procedure does not accept any parameters or return any values.

Usage Example:
    with conn.cursor() as cur:
  cur.execute("CALL bronze.truncate_bronze();")
  conn.commit()
===============================================================================
*/
with conn.cursor() as cur:
    cur.execute("""
    CREATE OR REPLACE PROCEDURE silver.load_silver()
    LANGUAGE plpgsql
    AS $$
    DECLARE
        start_time TIMESTAMP;
        end_time TIMESTAMP;
        batch_start_time TIMESTAMP;
        batch_end_time TIMESTAMP;
    BEGIN
        batch_start_time := clock_timestamp();
        RAISE NOTICE '=======================================';
        RAISE NOTICE 'Loading Silver Layer';
        RAISE NOTICE '=======================================';

        RAISE NOTICE '=======================================';
        RAISE NOTICE 'Loading CRM Tables';
        RAISE NOTICE '=======================================';

        start_time := clock_timestamp();
        RAISE NOTICE 'Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        RAISE NOTICE 'Inserting Table: silver.crm_cust_info';
        INSERT INTO silver.crm_cust_info(
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_material_status,
            cst_material_gndr,
            cst_create_date
        )
        SELECT cst_id,
               cst_key,
               TRIM(cst_firstname) AS cst_firstname,
               TRIM(cst_lastname) AS cst_lastname,
               CASE WHEN TRIM(UPPER(cst_material_status)) = 'S' THEN 'Single'
                    WHEN TRIM(UPPER(cst_material_status)) = 'M' THEN 'Married'
                    ELSE 'N/A' END cst_material_status,
               CASE WHEN TRIM(UPPER(cst_material_gndr)) = 'M' THEN 'Male'
                    WHEN TRIM(UPPER(cst_material_gndr)) = 'F' THEN 'Female'
                    ELSE 'N/A' END cst_material_gndr,
               cst_create_date
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY cst_id
                       ORDER BY cst_create_date DESC
                   ) AS flag_last
            FROM bronze.crm_cust_info
        ) t
        WHERE flag_last = 1;

        end_time := clock_timestamp();
        RAISE NOTICE '>>Load Duration: % seconds',
            EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER;

        start_time := clock_timestamp();
        RAISE NOTICE 'Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        RAISE NOTICE 'Inserting Table: silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info
        SELECT prd_id,
               REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id,
               REPLACE(SUBSTRING(prd_key,7,LENGTH(prd_key)),'-','_') AS prd_key,
               prd_nm,
               COALESCE(prd_cost,0) AS prd_cost,
               CASE WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
                    WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
                    WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'other Sales'
                    WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
                    ELSE 'n/a'
               END AS prd_line,
               CAST(prd_start_dt AS DATE) AS prd_start_dt,
               CAST(
                   LEAD(prd_start_dt) OVER (
                       PARTITION BY prd_key
                       ORDER BY prd_start_dt
                   ) - 1 AS DATE
               ) AS prd_end_dt
        FROM bronze.crm_prd_info;

        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds',
            EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER;

        start_time := clock_timestamp();
        RAISE NOTICE 'Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        RAISE NOTICE 'Inserting Table: silver.crm_sales_details';
        INSERT INTO silver.crm_sales_details
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE WHEN sls_order_dt = 0 OR LENGTH(CAST(sls_order_dt AS VARCHAR)) != 8
                 THEN NULL
                 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            CASE WHEN sls_order_dt = 0 OR LENGTH(CAST(sls_ship_dt AS VARCHAR)) != 8
                 THEN NULL
                 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            CASE WHEN sls_order_dt = 0 OR LENGTH(CAST(sls_due_dt AS VARCHAR)) != 8
                 THEN NULL
                 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,
            CASE WHEN sls_sales IS NULL OR sls_sales <= 0
                      OR sls_sales != sls_quantity * ABS(sls_price)
                 THEN sls_quantity * ABS(sls_price)
                 ELSE sls_sales
            END AS sls_sales,
            CASE WHEN sls_price IS NULL OR sls_price <= 0
                 THEN sls_sales / NULLIF(sls_quantity,0)
                 ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details
        WHERE sls_sales != sls_quantity * sls_price
           OR sls_sales IS NULL
           OR sls_quantity IS NULL
           OR sls_sales <= 0
           OR sls_quantity <= 0
           OR sls_price <= 0
        ORDER BY sls_sales, sls_quantity, sls_price;

        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds',
            EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER;

        start_time := clock_timestamp();
        RAISE NOTICE 'Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        RAISE NOTICE 'Inserting Table: silver.erp_cust_az12';
        INSERT INTO silver.erp_cust_az12
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LENGTH(cid))
                 ELSE cid
            END AS cid,
            CASE WHEN bdate > CURRENT_DATE THEN NULL
                 ELSE bdate
            END AS bdate,
            CASE WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
                 WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
                 ELSE 'N/A'
            END AS gen
        FROM bronze.erp_cust_az12;

        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds',
            EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER;

        start_time := clock_timestamp();
        RAISE NOTICE 'Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        RAISE NOTICE 'Inserting Table: silver.erp_loc_a101';
        INSERT INTO silver.erp_loc_a101
        SELECT
            REPLACE(cid,'-','') AS cid,
            CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
                 WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
                 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
                 ELSE TRIM(cntry)
            END AS cntry
        FROM bronze.erp_loc_a101;

        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds',
            EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER;

        start_time := clock_timestamp();
        RAISE NOTICE 'Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        RAISE NOTICE 'Inserting Table: silver.erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2
        SELECT id,
               cat,
               subcat,
               maintenance
        FROM bronze.erp_px_cat_g1v2;

        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds',
            EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER;

    END;
    $$;
    """)
conn.commit()
