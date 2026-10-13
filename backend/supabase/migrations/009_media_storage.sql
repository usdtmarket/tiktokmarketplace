insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values (
  'cityflow-media',
  'cityflow-media',
  false,
  52428800,
  array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','video/webm']::text[]
)
on conflict (id) do update set
  public=false,
  file_size_limit=52428800,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists cityflow_media_insert on storage.objects;
create policy cityflow_media_insert on storage.objects
for insert to authenticated
with check (
  bucket_id='cityflow-media'
  and (storage.foldername(name))[1]='listings'
  and (storage.foldername(name))[3]=(select auth.uid()::text)
);
drop policy if exists cityflow_media_select on storage.objects;
create policy cityflow_media_select on storage.objects
for select to authenticated
using (
  bucket_id='cityflow-media'
  and (storage.foldername(name))[1]='listings'
  and (storage.foldername(name))[3]=(select auth.uid()::text)
);
drop policy if exists cityflow_media_update on storage.objects;
create policy cityflow_media_update on storage.objects
for update to authenticated
using (
  bucket_id='cityflow-media'
  and (storage.foldername(name))[1]='listings'
  and (storage.foldername(name))[3]=(select auth.uid()::text)
)
with check (
  bucket_id='cityflow-media'
  and (storage.foldername(name))[1]='listings'
  and (storage.foldername(name))[3]=(select auth.uid()::text)
);
drop policy if exists cityflow_media_delete on storage.objects;
create policy cityflow_media_delete on storage.objects
for delete to authenticated
using (
  bucket_id='cityflow-media'
  and (storage.foldername(name))[1]='listings'
  and (storage.foldername(name))[3]=(select auth.uid()::text)
);