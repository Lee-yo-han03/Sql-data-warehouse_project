/*
====================================================================================
Stored Procedure: Load Bronze Layer(Source-> Bronze)
=====================================================================================
Script Purpose:
  This stored procedure loads data into the 'bronze' schema from external CSV files.
  It performs the following actions:
    - Truncates the bronze tables before loading date.
Parameters: 
  None.
  This stored procedure does not accept any parameters or return any values.
Usage example:
  with conn.cursor() as cur:
    cur.execute("CALL bronze.truncate_bronze();")

conn.commit()
=====================================================================================
*/
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
