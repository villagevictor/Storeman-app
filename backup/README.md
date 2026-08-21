# Storeman Backup Strategy

The Storeman system must preserve:

- Products
- Warehouses
- Suppliers
- Customers
- Stock In
- Stock Out
- Sales
- Invoices
- Transaction history
- Low-stock configuration
- Daily reports
- Application settings

Primary backup:
Supabase Cloud

Secondary backup:
Local export / restore

Rule:
Never overwrite cloud data without validation.
