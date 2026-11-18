\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL timezone = 'UTC';
SET LOCAL datestyle = 'ISO, YMD';

-- Compare these fingerprints before and after migrations. New nullable columns
-- and hostname metadata are intentionally excluded from the historical payload.
SELECT format(
  'SELECT %L AS relation, count(*), md5(coalesce(string_agg(md5((to_jsonb(row) - %L::text[])::text), '''' ORDER BY id), '''')) FROM public.%I AS row',
  tablename,
  CASE tablename WHEN 'games' THEN '{slug}' WHEN 'players' THEN '{removed_at,table_captain}'
    WHEN 'session_frames' THEN '{sequence,format_version,kind,game_key,payload,occurred_at,context_frame_id,corrects_frame_id}'
    ELSE '{}' END,
  tablename
)
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT IN ('schema_migrations', 'ar_internal_metadata')
ORDER BY tablename
\gexec

SELECT format(
  'SELECT %L AS sequence, last_value, is_called FROM public.%I',
  sequencename, sequencename
)
FROM pg_sequences WHERE schemaname = 'public'
ORDER BY sequencename
\gexec
COMMIT;
