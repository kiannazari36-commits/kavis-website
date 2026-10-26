-- process-material keeps a lesson PDF's page texts next to the file (<user>/<lesson>/pages.json), so later batches
-- do not open the whole PDF again (that used up a run's CPU time on big PDFs). Allow JSON in the materials bucket.
update storage.buckets
set allowed_mime_types = array_append(allowed_mime_types, 'application/json')
where id = 'materials' and not ('application/json' = any (allowed_mime_types));
