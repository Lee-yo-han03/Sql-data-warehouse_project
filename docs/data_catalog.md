# Data Catalog for Gold Layer

## Overview

The Gold Layer represents business-level data designed to support analytical and reporting use cases. It consists of dimension tables and fact tables, following a Star Schema structure.

All Gold Layer objects are created as **Views** in PostgreSQL.

---

### 1. gold.dim_customers

- **Purpose:** Stores customer details enriched with demographic and geographic data.
- **Object Type:** View

| Column Name | Data Type | Description |
|---|---|---|
| customer_key | BIGINT | Surrogate key generated using ROW_NUMBER(), uniquely identifying each customer record in the dimension. |
| customer_id | INTEGER | Unique numerical identifier assigned to the customer in the source CRM system. |
| customer_number | VARCHAR(50) | Alphanumeric identifier representing the customer, used for tracking and referencing. |
| first_name | VARCHAR(50) | The customer's first name. |
| last_name | VARCHAR(50) | The customer's last name or family name. |
| country | VARCHAR(50) | The country of residence for the customer (e.g., Australia). |
| marital_status | VARCHAR(50) | The marital status of the customer (e.g., Married, Single). |
| gender | VARCHAR(50) | The customer's gender, integrated from CRM and ERP sources (e.g., Male, Female, N/A). |
| birthdate | DATE | The date of birth of the customer, formatted as YYYY-MM-DD. |
| cst_create_date | DATE | The date when the customer record was created in the source CRM system. |

---

### 2. gold.dim_products

- **Purpose:** Provides descriptive information about products, including their categories, attributes, and pricing information.
- **Object Type:** View

| Column Name | Data Type | Description |
|---|---|---|
| product_key | BIGINT | Surrogate key generated using ROW_NUMBER(), uniquely identifying each product record in the dimension. |
| product_id | INTEGER | Unique identifier assigned to the product in the source CRM system. |
| product_number | VARCHAR(50) | Structured alphanumeric code representing the product. |
| product_name | VARCHAR(50) | Descriptive name of the product, including details such as type, color, and size. |
| category_id | VARCHAR(50) | Identifier linking the product to its product category. |
| category | VARCHAR(50) | The broader classification of the product (e.g., Bikes, Components). |
| subcategory | VARCHAR(50) | A more detailed classification of the product within its category. |
| maintenance | VARCHAR(50) | Indicates whether the product requires maintenance (e.g., Yes, No). |
| cost | INTEGER | The product's base cost, measured in whole currency units. |
| product_line | VARCHAR(50) | The product line or series to which the product belongs (e.g., Road, Mountain). |
| start_date | DATE | The date when the product became available for sale or use. |
| prd_end_dt | DATE | The product's end date. NULL indicates that the product is currently active. |

**Note:** The View filters records using `WHERE pn.prd_end_dt IS NULL`, so only currently active products are included in this dimension.

---

### 3. gold.fact_sales

- **Purpose:** Stores transactional sales data for analytical purposes, connecting customer and product dimensions through surrogate keys.
- **Object Type:** View

| Column Name | Data Type | Description |
|---|---|---|
| order_number | VARCHAR(50) | Identifier representing the sales order (e.g., SO54496). |
| product_key | BIGINT | Surrogate key linking the sales transaction to the product dimension. |
| customer_key | BIGINT | Surrogate key linking the sales transaction to the customer dimension. |
| order_date | DATE | The date when the order was placed. |
| shipping_date | DATE | The date when the order was shipped to the customer. |
| due_date | DATE | The payment due date associated with the order. |
| sales_amount | INTEGER | The total monetary value of the sales line item. |
| quantity | INTEGER | The number of units of the product ordered. |
| sls_price | INTEGER | The selling price per unit of the product. |

---

## Data Modeling Notes

1. **Star Schema:** The Fact Table (`fact_sales`) is connected to two Dimension Tables (`dim_customers` and `dim_products`).

2. **Surrogate Keys:** Customer and product identifiers are replaced with warehouse-generated surrogate keys to establish relationships between fact and dimension tables.

3. **Business Logic:** Customer demographic and geographic attributes are integrated from CRM and ERP sources.

4. **Current Products:** The product dimension includes only active products (`prd_end_dt IS NULL`).

5. **Data Integrity:** Foreign key integrity should be validated to ensure that every customer and product key in the Fact Table has a corresponding record in its respective Dimension Table.
