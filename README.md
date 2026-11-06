# Respack ERP — fictional demo preview and ERP foundation

## Preview the demo

The preview is a static, read-only UI walkthrough populated with a fabricated dataset. It includes fictional customer and supplier records, sales, requisitions and approval log, goods receipts, inventory lots and issues to work orders, BOMs, production/routing, quality rolls, dispatches, finance examples, labor aliases, maintenance/downtime, management metrics, and CSV export for the currently displayed table.

All names, identifiers, dates, quantities, prices, records, approvals, and metrics in `demo-data.json` are invented. The data is not scraped, not real Respack data, not evidence of actual operations, and not suitable for operational, HR, purchasing, tax, or accounting decisions. The preview is read-only and does not persist edits.

For local preview, serve the repository directory using any static HTTP server, then open `/preview.html` through that server. Example with Python:

```bash
python -m http.server 8000
```

Then visit `http://localhost:8000/preview.html`. Opening the HTML directly using a `file://` URL may prevent the browser from loading `demo-data.json` due to browser security restrictions.

## ERP foundation

`index.html` is the authenticated application foundation. It requires a configured backend; the demo preview does not require credentials and should not be used to enter real company data. The current authenticated foundation targets Supabase. A future MSSQL deployment would require an API/backend layer; never connect the browser directly to SQL Server or put database credentials in frontend files.

## Production-readiness

This project is not a validated production ERP. The static demo is for interface review only. Before live use, implement and validate the backend, permissions, workflow controls, audit trail, backups and recovery, data retention, security, and business rules with Respack process owners. Financial entries in the preview are not a ledger and are not compliant accounting reports.
