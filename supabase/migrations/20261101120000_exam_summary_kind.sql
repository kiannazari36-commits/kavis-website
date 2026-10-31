-- "Sınav özeti": a reading page the server writes from the topics asked in the lecturer's sample questions.
-- It is a lesson row of its own kind, so the reader, highlights and the assistant treat it like a PDF, while the
-- course page, the "read" average, the trial lesson count and quiz making (which only look at pdf / photo) skip it.
alter type public.material_kind add value if not exists 'exam_summary';
