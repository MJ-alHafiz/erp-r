# Respack ERP — fictional demo app and ERP foundation

This repository now includes a more polished ERP-style demo interface, built as a static front-end mockup with a mock login and editable demo data stored in browser local storage.

## What is included

- authenticated demo login flow
- sidebar navigation for major ERP modules
- overview dashboard with KPI cards
- customer master and sales order screens
- purchasing requisitions and supplier view
- inventory and material lot tracking
- production work-order management
- quality roll and inspection data
- dispatch/delivery and finance/reporting views
- forms to add demo data without a backend
- CSV data export for the currently displayed table view (not yet a full export engine)

## Demo credentials

- Email: admin@respack.demo
- Password: respack123

## Run locally

From the repo root:

```bash
python -m http.server 8000
```

Then open:

```text
http://localhost:8000/preview.html
```

## Important notice

This is still a fictional demo and not a live ERP system. It intentionally contains made-up customer, supplier, financial, production, and quality records for design and workflow review only. It must not be treated as operational data, audited accounting, or a live manufacturing system.
