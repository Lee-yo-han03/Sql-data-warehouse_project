#This script contains codes installing tools to run Postgresql in Google colab and creating the tables in the bronze schema
# PostgreSQL 서버 및 추가 기능 설치
!apt-get update -qq
!apt-get install -y postgresql postgresql-contrib

# PostgreSQL 서버 시작
!service postgresql start

# 서버 상태 확인
!pg_lsclusters
%pip install -q psycopg2-binary

# 연습용 PostgreSQL 계정 비밀번호 설정
!sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'colab_local_only';"

print("Python 연결 라이브러리 및 계정 설정 완료")
!service postgresql start
!sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
import psycopg2

# 1. PostgreSQL 서버 시작
!service postgresql start

# 2. PostgreSQL 접속 설정
DB_CONFIG = {
    "user": "postgres",
    "password": "postgres",
    "host": "127.0.0.1",
    "port": 5432
}

# 3. 기본 데이터베이스에 접속
conn = psycopg2.connect(
    dbname="postgres",
    **DB_CONFIG
)
conn.autocommit = True

print("PostgreSQL 연결 성공!")
print("연결 상태:", conn.closed)  # 0이면 연결 중

# 4. datawarehouse 데이터베이스 확인 및 생성
with conn.cursor() as cur:
    cur.execute("""
        SELECT 1
        FROM pg_database
        WHERE datname = 'datawarehouse';
    """)

    if cur.fetchone() is None:
        cur.execute("CREATE DATABASE datawarehouse;")
        print("datawarehouse 데이터베이스 생성 완료")
    else:
        print("datawarehouse 데이터베이스가 이미 존재합니다.")

conn.close()

# 5. datawarehouse 데이터베이스에 접속
conn = psycopg2.connect(
    dbname="datawarehouse",
    **DB_CONFIG
)

# 6. Bronze, Silver, Gold 스키마 생성
with conn.cursor() as cur:
    cur.execute("CREATE SCHEMA IF NOT EXISTS bronze;")
    cur.execute("CREATE SCHEMA IF NOT EXISTS silver;")
    cur.execute("CREATE SCHEMA IF NOT EXISTS gold;")

    cur.execute("""
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name IN ('bronze', 'silver', 'gold')
        ORDER BY schema_name;
    """)

    print("\n생성된 스키마:")
    for row in cur.fetchall():
        print(row[0])

conn.commit()

print("\n데이터 웨어하우스 초기 설정 완료!")
print("Datawarehouse 연결 상태:", conn.closed)
#Making the bronze layer tables
#The drop key is deleting the existing table, so key IF NOT EXISTS is not necessary. JUST TO STUDY
conn.rollback()
with conn.cursor() as cur:
  cur.execute("""DROP TABLE IF EXISTS bronze.crm_cust_info;""" )
  cur.execute("""CREATE TABLE IF NOT EXISTS bronze.crm_cust_info(
                  cst_id INTEGER,
                  cst_key VARCHAR(50),
                  cst_firstname VARCHAR(50),
                  cst_lastname VARCHAR(50),
                  cst_material_status VARCHAR(50),
                  cst_material_gndr VARCHAR(50),
                  cst_create_date DATE);""")

  cur.execute("""DROP TABLE IF EXISTS bronze.crm_prd_info;
                 CREATE TABLE IF NOT EXISTS bronze.crm_prd_info(
                  prd_id INTEGER,
                  prd_key VARCHAR(50),
                  prd_nm VARCHAR(50),
                  prd_cost INTEGER,
                  prd_line VARCHAR(50),
                  prd_start_dt DATE,
                  prd_end_dt DATE);""")

  cur.execute("""DROP TABLE IF EXISTS bronze.crm_sales_details;
                 CREATE TABLE IF NOT EXISTS bronze.crm_sales_details(
                  sls_ord_num VARCHAR(50),
                  sls_prd_key VARCHAR(50),
                  sls_cust_id VARCHAR(50),
                  sls_order_dt INTEGER,
                  sls_ship_dt INTEGER,
                  sls_due_dt INTEGER,
                  sls_sales INTEGER,
                  sls_quantity INTEGER,
                  sls_price INTEGER);""")

  cur.execute("""DROP TABLE IF EXISTS bronze.erp_cust_az12;
                 CREATE TABLE IF NOT EXISTS bronze.erp_cust_az12(
                  cid VARCHAR(50),
                  bdate DATE,
                  gen VARCHAR(50));""")

  cur.execute("""DROP TABLE IF EXISTS bronze.erp_loc_a101;
                 CREATE TABLE IF NOT EXISTS bronze.erp_loc_a101(
                  cid VARCHAR(50),
                  cntry VARCHAR(50));""")

  cur.execute("""DROP TABLE IF EXISTS  bronze.erp_px_cat_g1v2;
                 CREATE TABLE IF NOT EXISTS bronze.erp_px_cat_g1v2(
                  id VARCHAR(50),
                  cat VARCHAR(50),
                  subcat VARCHAR(50),
                  maintenance VARCHAR(50));""")
  conn.commit()

#COPY INSTEAD OF BULT INSERT
from google.colab import files
uploaded = files.upload()
#파일 업로드 되었는지 확인
import os
print(os.listdir('/content'))
#ZIP파일 풀기
import zipfile
zip_path = "/content/sql-data-warehouse-project.zip"
extract_path = "/content/sql-data-warehouse-project"
with zipfile.ZipFile(zip_path,"r") as z:
  z.extractall(extract_path)
print(os.listdir(extract_path))
import os

for root, dirs, files in os.walk("/content"):
    if "cust_az12.csv" in files:
        print(os.path.join(root, "cust_az12.csv"))
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
