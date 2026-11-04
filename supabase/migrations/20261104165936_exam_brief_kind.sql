-- "Sınav gecesi özeti": the short exam-night version of the exam summary (Edge exam-summary, mode "brief").
-- A lesson row of its own kind, next to the full exam_summary; like it, the course page's PDF list, the "read" average,
-- the trial lesson count and quiz making (which only look at pdf / photo) skip it.
alter type public.material_kind add value if not exists 'exam_brief';
