-- "Hesap bilgilerimi iste": next to the JSON copy, export-data now also puts a readable HTML report
-- (<user>/<same name>.html) in the private bucket 'exports'. The bucket only allowed JSON, so allow HTML too.
-- The nightly purge (delete-account) removes both files after 7 days; no table change is needed.
update storage.buckets set allowed_mime_types = array['application/json', 'text/html'] where id = 'exports';
