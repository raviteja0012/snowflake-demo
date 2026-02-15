# Wholesale Hub - Claude Code Project Context

## Business Overview
Wholesale Hub is a B2B marketplace for wholesale supplies serving gas stations, smoke shops, and convenience stores. The system emphasizes **user-friendly design for less tech-savvy users** through:
- Simple, intuitive interfaces with large buttons and clear icons
- Visual feedback (colors, images) over text-heavy displays
- Voice/audio confirmation for scanning operations
- Offline-first mobile app with background sync

## Architecture

### Data Flow
```
Suppliers → Inbound Channels → RAW → STAGING → CURATED → Mobile App/Web
              (Email/File/API)    (Parse)  (Validate)  (Business Data)
```

### Database: Snowflake (3-Layer Medallion Architecture)
- **WH_RAW**: Raw ingested data with 7-day retention
  - `INBOUND` schema: Email, file, API payloads
  - `SCANNING` schema: Barcode scan events
- **WH_STAGING**: Transformed and validated data
  - `RECEIPTS` schema: Staged receipt data
  - `ERRORS` schema: Validation failures
- **WH_CURATED**: Production business data
  - `MASTER` schema: Products, suppliers, customers, users
  - `INVENTORY` schema: Receipts, on-hand, transactions
  - `PURCHASING` schema: Purchase orders
  - `SALES` schema: Customer orders

### Key Files
| File | Purpose |
|------|---------|
| `databases/WH_RAW/tables/*.sql` | Raw inbound data tables |
| `databases/WH_STAGING/tables/*.sql` | Staging tables for validation |
| `databases/WH_CURATED/tables/*.sql` | Production business tables |
| `databases/WH_CURATED/procedures/*.sql` | ETL stored procedures |
| `api/openapi.yaml` | REST API specification |
| `deployment/deploy_all.sql` | Master deployment script |

## Coding Standards

### Snowflake SQL
- Use `CREATE OR REPLACE` for idempotent deployments
- Include `COMMENT` on all tables and schemas
- Use `VARCHAR(100)` for IDs, `VARCHAR(50)` for codes
- Use `VARIANT` for flexible JSON data
- Naming conventions:
  - Tables: `SINGULAR_NAME` (e.g., `PRODUCT_MASTER`)
  - Procedures: `SP_ACTION_ENTITY` (e.g., `SP_PROCESS_INBOUND_FILE`)
  - Sequences: `SEQ_ENTITY_ID` (e.g., `SEQ_RECEIPT_NUMBER`)
  - Views: `V_DESCRIPTION` (e.g., `V_SCAN_SUMMARY`)

### ID Formats
- Receipt IDs: `RCP-{timestamp}` (e.g., `RCP-20240115143022123`)
- Line IDs: `LN-{parent_id}-{line_number}`
- Transaction IDs: `TXN-{ref_id}-{line_number}`
- Alert IDs: `ALT-{ref_id}-{line_number}`

### Status Workflows
**Receipt Status:**
```
PENDING_DOCUMENT → PARSED → AWAITING_ARRIVAL → PARTIAL_RECEIVED → FULLY_RECEIVED → CLOSED
                         ↘ VALIDATION_ERROR                    ↘ DISPUTED
```

**Processing Status (RAW):**
```
PENDING → PROCESSED
       ↘ FAILED
```

## Common Development Tasks

### Add New Inbound Channel
1. Create RAW table in `databases/WH_RAW/tables/`
2. Create parsing procedure in `databases/WH_CURATED/procedures/`
3. Add API endpoint in `api/openapi.yaml`
4. Update deployment script

### Add New Product Field
1. Modify `PRODUCT_MASTER` table
2. Update staging line table if needed
3. Update API schemas in OpenAPI spec
4. Test barcode lookup endpoint

### Create New Report
1. Create view in `databases/WH_CURATED/views/`
2. Add API endpoint for data access
3. Update deployment script

## Testing Checklist
- [ ] All tables deploy without errors
- [ ] Procedures handle NULL values gracefully
- [ ] Idempotency checks prevent duplicates
- [ ] Error logging captures all failures
- [ ] API responses match OpenAPI schema

## User Experience Principles
When modifying UI-facing components:
1. **Large touch targets** - minimum 44x44px for mobile
2. **Clear visual feedback** - GREEN=success, RED=error, YELLOW=warning
3. **Audio confirmation** - scanning should play tones
4. **Simple language** - avoid technical jargon
5. **Offline support** - queue actions when disconnected
6. **Progress indicators** - show "15 of 20 items scanned"

## Sample Prompts for Claude Code

### Schema Changes
```
Add a CARRIER_MASTER table to WH_CURATED.MASTER with carrier_id, name,
tracking_url_template, and typical_delivery_days. Follow existing table patterns.
```

### Procedure Updates
```
Update SP_COMPLETE_RECEIPT to also create low stock alerts when
inventory falls below reorder_point after receiving.
```

### API Additions
```
Add a GET /inventory/alerts endpoint to return open inventory alerts
for the mobile app notifications screen.
```

### Data Quality
```
Create a procedure SP_VALIDATE_PRODUCT_MASTER that checks for:
- Missing UPC codes
- Duplicate SKUs
- Invalid category references
```
