#Script Purpose: 
  This stored procedure trunscate process and then loads data into the 'bronze' schema from external CSV files.
  It performs the following actions:
  -Truncates the bronze tables using procedure before loading data
  -During the truncate process, it measure the duration of the process 
  -Instead of using 'Bulk Insert', we use copy in postgresql to load data from csv files to bronze tables.
#Parameter
  -None 
  This stored procedure does not accept any parameter or return any values
  
  #How to make a procedure.(we can include the copy work in here!)
#cur.execute("TRUNCATE TABLE bronze.crm_cust_info;")#If we don't use this code, then the number of row becomes doubled everytime we implement it
#RAISE NOTICE 'ERROR OCCERED%', SQLERRM; #SHOUING THE CONTENT OF THE ERROR
#RAISE; #RAISE THE ERROR SO THAT WE CAN PROCEDE NEXT STEP TO DEAL WITH THE ERROR
conn.rollback()
with conn.cursor() as cur:
    cur.execute("""
        CREATE OR REPLACE PROCEDURE bronze.truncate_bronze()
        LANGUAGE plpgsql
        AS $$
        DECLARE
            start_time TIMESTAMP;
            end_time TIMESTAMP;
        BEGIN
            -- CRM 테이블 초기화 시간 측정
            start_time := clock_timestamp();

            TRUNCATE TABLE
                bronze.crm_cust_info,
                bronze.crm_prd_info,
                bronze.crm_sales_details;

            end_time := clock_timestamp();

            RAISE NOTICE 'CRM tables truncated';
            RAISE NOTICE 'CRM truncate duration: % seconds',
                ROUND(
                    EXTRACT(EPOCH FROM (end_time - start_time))::numeric,
                    3
                );

            -- ERP 테이블 초기화 시간 측정
            start_time := clock_timestamp();

            TRUNCATE TABLE
                bronze.erp_cust_az12,
                bronze.erp_loc_a101,
                bronze.erp_px_cat_g1v2;

            end_time := clock_timestamp();

            RAISE NOTICE 'ERP tables truncated';
            RAISE NOTICE 'ERP truncate duration: % seconds',
                ROUND(
                    EXTRACT(EPOCH FROM (end_time - start_time))::numeric,
                    3
                );

        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Error occurred during truncation';
                RAISE NOTICE 'Error details: %', SQLERRM;
                RAISE;
        END;
        $$;
    """)

conn.commit()
print("Bronze truncate procedure created successfully!")
# 이전 NOTICE 메시지 초기화
conn.notices.clear()

# 프로시저 실행
with conn.cursor() as cur:
    cur.execute("CALL bronze.truncate_bronze();")

conn.commit()
# Colab 출력창에 메시지 표시
for notice in conn.notices:
    print(notice.strip())
#I decided to use Copy instead of using BULK INSERT because there's no bulk insert concept in postgresql
with conn.cursor() as cur:
    cur.execute("""CALL bronze.truncate_bronze();""")
    cur.execute("""
        COPY bronze.crm_cust_info
        FROM '/content/sql-data-warehouse-project/sql-data-warehouse-project/datasets/source_crm/cust_info.csv'
        WITH (
            FORMAT CSV,
            HEADER TRUE,
            DELIMITER ','
        );""")
    cur.execute("""
        COPY bronze.crm_prd_info
        FROM '/content/sql-data-warehouse-project/sql-data-warehouse-project/datasets/source_crm/prd_info.csv'
        WITH (
            FORMAT CSV,
            HEADER TRUE,
            DELIMITER ','
            );""")
    cur.execute("""
        COPY bronze.crm_sales_details
        FROM '/content/sql-data-warehouse-project/sql-data-warehouse-project/datasets/source_crm/sales_details.csv'
        WITH (
            FORMAT CSV,
            HEADER TRUE,
            DELIMITER ','
            );""")
    cur.execute("""
        COPY bronze.erp_cust_az12
        FROM '/content/sql-data-warehouse-project/sql-data-warehouse-project/datasets/source_erp/CUST_AZ12.csv'
        WITH (
            FORMAT CSV,
            HEADER TRUE,
            DELIMITER ','
            );""")
    cur.execute("""
        COPY bronze.erp_loc_a101
        FROM '/content/sql-data-warehouse-project/sql-data-warehouse-project/datasets/source_erp/LOC_A101.csv'
        WITH (
            FORMAT CSV,
            HEADER TRUE,
            DELIMITER ','
            );""")
    cur.execute("""
        COPY bronze.erp_px_cat_g1v2
        FROM '/content/sql-data-warehouse-project/sql-data-warehouse-project/datasets/source_erp/PX_CAT_G1V2.csv'
        WITH (
            FORMAT CSV,
            HEADER TRUE,
            DELIMITER ','
            );""")
conn.commit()
conn.rollback()
tables = [
    "crm_cust_info",
    "crm_prd_info",
    "crm_sales_details",
    "erp_cust_az12",
    "erp_loc_a101",
    "erp_px_cat_g1v2"
]
with conn.cursor() as cur:
  for table in tables:
    cur.execute(f"""SELECT COUNT(*) FROM bronze.{table};""")
    row_count=cur.fetchone()[0]
    print(f"{table}:{row_count}")
