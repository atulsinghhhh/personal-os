-- Extensions required by the schema.
-- pgcrypto provides gen_random_uuid() used as a server-side safety-net default
-- for primary keys (the Flutter client always generates and sends its own
-- UUIDv4 client-side, required for offline-first creation).
create extension if not exists pgcrypto;
