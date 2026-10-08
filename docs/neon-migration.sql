-- NaghmaHub / sm3ha -> Neon PostgreSQL baseline schema
-- Target database: sm3ha
-- Safe to run on an empty database. No DROP/TRUNCATE/DELETE statements are used.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  open_id text NOT NULL UNIQUE,
  name text,
  email text,
  login_method text,
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_signed_in timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS artists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  normalized_name text NOT NULL,
  slug text NOT NULL UNIQUE,
  image_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS albums (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  normalized_title text NOT NULL,
  slug text NOT NULL UNIQUE,
  artist_id uuid REFERENCES artists(id) ON DELETE SET NULL,
  image_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS songs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  normalized_title text NOT NULL,
  slug text NOT NULL UNIQUE,
  artist_id uuid REFERENCES artists(id) ON DELETE SET NULL,
  album_id uuid REFERENCES albums(id) ON DELETE SET NULL,
  provider text NOT NULL DEFAULT 'youtube',
  provider_video_id text NOT NULL,
  provider_url text,
  opaque_token_hash text NOT NULL UNIQUE,
  thumbnail_url text,
  duration_seconds integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','removed')),
  rights_status text NOT NULL DEFAULT 'metadata_only' CHECK (rights_status IN ('demo','licensed','metadata_only','removed')),
  view_count integer NOT NULL DEFAULT 0,
  is_featured boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(provider, provider_video_id)
);

CREATE TABLE IF NOT EXISTS media_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  song_id uuid NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  format text NOT NULL CHECK (format IN ('mp3','mp4')),
  quality text NOT NULL,
  size_bytes bigint,
  storage_key text,
  status text NOT NULL DEFAULT 'unavailable' CHECK (status IN ('ready','processing','unavailable')),
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS conversion_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  song_id uuid NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  format text NOT NULL CHECK (format IN ('mp3','mp4')),
  quality text NOT NULL,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','processing','ready','failed','expired','cancelled')),
  progress integer NOT NULL DEFAULT 0,
  error_message text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  expires_at timestamptz
);

CREATE TABLE IF NOT EXISTS search_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query text NOT NULL,
  song_id uuid REFERENCES songs(id) ON DELETE SET NULL,
  hashed_ip text,
  user_agent text,
  path text NOT NULL DEFAULT '/search',
  result_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS takedown_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  song_id uuid REFERENCES songs(id) ON DELETE SET NULL,
  claimant_name text NOT NULL,
  claimant_email text NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewing','resolved','rejected')),
  evidence_url text,
  admin_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by text
);

CREATE TABLE IF NOT EXISTS import_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'admin',
  total_rows integer NOT NULL DEFAULT 0,
  accepted_rows integer NOT NULL DEFAULT 0,
  duplicate_rows integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('preview','completed','failed')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS import_rows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
  provider_video_id text NOT NULL,
  title text NOT NULL,
  artist text NOT NULL,
  slug text,
  status text NOT NULL DEFAULT 'accepted' CHECK (status IN ('accepted','duplicate','failed')),
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name text NOT NULL CHECK (event_name IN ('page_view','search','song_view','media_view','conversion_start','admin_action')),
  path text NOT NULL,
  query text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  session_hash text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS site_settings (
  key text PRIMARY KEY,
  value text NOT NULL DEFAULT '',
  value_type text NOT NULL DEFAULT 'text' CHECK (value_type IN ('text','boolean','number','json')),
  description text,
  updated_by text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS catalog_keywords (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query text NOT NULL,
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  language text NOT NULL DEFAULT 'ar',
  source text NOT NULL DEFAULT 'catalog',
  result_count integer NOT NULL DEFAULT 0,
  result_slugs text[] NOT NULL DEFAULT '{}',
  indexable boolean NOT NULL DEFAULT true,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','hidden','noindex')),
  search_count integer NOT NULL DEFAULT 0,
  last_searched_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS artists_normalized_name_idx ON artists(normalized_name);
CREATE INDEX IF NOT EXISTS albums_artist_id_idx ON albums(artist_id);
CREATE INDEX IF NOT EXISTS songs_normalized_title_idx ON songs(normalized_title);
CREATE INDEX IF NOT EXISTS songs_rights_status_idx ON songs(rights_status);
CREATE INDEX IF NOT EXISTS songs_artist_id_idx ON songs(artist_id);
CREATE INDEX IF NOT EXISTS songs_album_id_idx ON songs(album_id);
CREATE INDEX IF NOT EXISTS songs_updated_at_idx ON songs(updated_at DESC);
CREATE INDEX IF NOT EXISTS search_logs_created_at_idx ON search_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS search_logs_query_idx ON search_logs(query);
CREATE INDEX IF NOT EXISTS takedown_requests_created_at_idx ON takedown_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS analytics_events_created_at_idx ON analytics_events(created_at DESC);
CREATE INDEX IF NOT EXISTS analytics_events_event_name_idx ON analytics_events(event_name, created_at DESC);
CREATE INDEX IF NOT EXISTS analytics_events_path_idx ON analytics_events(path, created_at DESC);
CREATE INDEX IF NOT EXISTS catalog_keywords_indexable_idx ON catalog_keywords(indexable, status, updated_at DESC);
CREATE INDEX IF NOT EXISTS catalog_keywords_language_idx ON catalog_keywords(language, status);
CREATE INDEX IF NOT EXISTS catalog_keywords_result_count_idx ON catalog_keywords(result_count DESC);

INSERT INTO site_settings (key,value,value_type,description) VALUES
 ('site_name','نغمة','text','الاسم الظاهر للموقع'),
 ('site_description','مساحة عربية لاكتشاف الأغاني والموسيقى.','text','الوصف العام وSEO'),
 ('ads_enabled','false','boolean','تفعيل خانات الإعلانات المصرح بها'),
 ('ads_provider','none','text','مزود الإعلانات الحالي'),
 ('contact_email','','text','بريد التواصل وطلبات السحب')
ON CONFLICT (key) DO NOTHING;
