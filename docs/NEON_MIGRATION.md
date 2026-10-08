# Neon migration plan

The fork `cpanel60-hue/sm3ha` is currently identical to the upstream `amazonkadipi-collab/sm3ha` at commit `4b3eaf4d5d3ab2491a7b4c886578f05c7e70cfc5`. Keep this fork as the backup before deleting the upstream repository.

## Neon target prepared

A separate PostgreSQL database named `sm3ha` has been created inside the existing Neon project `movie1` on the production branch. It is isolated from the existing `neondb` database used by the movie project.

The baseline schema is in `docs/neon-migration.sql` and has already been applied successfully to the Neon `sm3ha` database.

## Important: code is not switched yet

The application still contains Supabase compatibility code. Do **not** delete the upstream Supabase-backed project/data until the production rows have been copied and the application has been switched to Neon.

The repository does not contain the production Supabase rows or the service-role secret, so the actual data copy cannot be safely completed from GitHub source code alone.

## Required production data migration

Before deleting the old Supabase project:

1. Obtain the existing Supabase project credentials for project `dfocwmbnazuygbazdctn`.
2. Export/copy these tables to Neon, preserving relationships and IDs where possible:
   - `artists`
   - `albums`
   - `songs`
   - `catalog_keywords`
   - `search_logs`
   - `takedown_requests`
   - `import_batches`
   - `import_rows`
   - `analytics_events`
   - `site_settings`
   - `users` if populated
3. Verify row counts and representative records.
4. Switch the app to the Neon `sm3ha` database and remove the Supabase runtime dependency.
5. Deploy and verify search, song pages, sitemap endpoints, admin import, analytics and takedown flows.
6. Only after those checks pass should the old upstream repository/Supabase resources be removed.

## Do not copy secrets

Never commit `SUPABASE_SERVICE_ROLE_KEY`, `DATABASE_URL`, YouTube keys, CloudConvert keys, admin passwords, or session secrets to GitHub.

