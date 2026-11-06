# Respack Manufacturing ERP (foundation)

A small, authenticated ERP foundation for Respack flexible-packaging operations. It replaces the original browser-only mockup with Supabase-backed records and tenant-scoped database access for sales orders, work orders, material lots/receipts, and QC roll traceability.

## Important scope and production-readiness notice

This is an operational ERP **foundation/MVP**, not a complete or independently validated production ERP. It does not yet include purchasing workflows, supplier/customer master-data screens, BOM/recipe management, costing/accounting, payroll, maintenance, dispatch, statutory/tax reporting, or regulatory validation. Before relying on it for plant operations, have Respack process owners verify the workflows and calculations; have a database administrator/security reviewer validate access policies, backups, recovery, and audit requirements; and deploy in a controlled environment. Do not use sample data for real operational decisions.

The app requires a Supabase project for persistent data and authentication. It is not safe to treat a static HTML file or browser local storage as the source of truth for a business ERP.

## Setup

1. Create a Supabase project under Respack-controlled ownership. Enable email authentication and decide on email-confirmation and password policies.
2. In the Supabase SQL editor, run `supabase/schema.sql` as the project administrator.
3. Create `config.js` from `config.example.js`; fill in the project URL and the project's **publishable/anon key**. Never put a `service_role` or other secret key in this file or browser code.
4. Provision the first user and organization from the SQL editor, replacing the example values below. The user must sign up first and confirm their email if confirmation is enabled.

```sql
insert into public.organizations (name) values ('Respack Manufacturing') returning id;
-- Use the returned organization UUID and the user's Auth UUID:
insert into public.organization_members (organization_id, user_id, role)
values ('<organization-uuid>', '<auth-user-uuid>', 'owner');
```

5. Serve the repository over HTTPS using a static host (for local testing, any local static HTTP server is fine); open `index.html`, create/sign in to the provisioned account, and confirm the organization is displayed. The first signed-in user still needs its membership provisioned in step 4.
6. Back up the database, configure monitoring, and test role-based access and restore procedures before production use.

`config.js` is git-ignored; do not commit real project configuration. The browser uses the public anon key, while row-level security (RLS) restricts each account to organizations in which it has a membership. RLS is not a substitute for reviewing project settings, database grants, authentication policies, or operational security.

## Current functions

- Email sign-in/sign-up and organization membership lookup.
- Tenant-scoped sales order creation and register.
- Work-order planning linked to sales orders, with production/scrap fields in the database.
- Material catalog and lot receipts through a database function; each receipt is recorded in an inventory transaction and updates lot on-hand quantity atomically.
- QC roll/barcode records linked to work orders.
- Dashboard counts and production output from persisted records.

Changes to production output/status and material issues, role-management screens, import/export, and full audit/history reporting remain future work; the current UI must not be interpreted as capturing those workflows.
