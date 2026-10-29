-- "Hatalarım" cards remember which lesson (PDF) they came from, so they go away with it.
-- Before this, a mistake card kept no link to its lesson: delete the lesson (or its quiz) and the card stayed forever
-- and came back in the plan's "mistakes" task, oldest first.

alter table public.flashcards
  add column material_id uuid references public.materials(id) on delete cascade;

create index flashcards_material on public.flashcards (material_id) where material_id is not null;

-- Old mistake cards: find the quiz question they were made from (the card text is the question, then an empty line, then the options).
update public.flashcards f
   set material_id = s.mat
  from (
    select f2.id,
           (select coalesce(mt.material_id, z.material_id)
              from public.quiz_questions x
              join public.quizzes z on z.id = x.quiz_id
              left join public.material_topics mt on mt.id = x.topic_id
             where x.user_id = f2.user_id
               and (f2.question = x.text or starts_with(f2.question, x.text || E'\n\n'))
               and coalesce(mt.material_id, z.material_id) is not null
             limit 1) as mat
      from public.flashcards f2
     where f2.from_mistake
  ) s
 where f.id = s.id and s.mat is not null;

-- Mistake cards whose question exists in no quiz any more (the quiz or lesson was deleted): remove them.
delete from public.flashcards f
 where f.from_mistake
   and not exists (
     select 1 from public.quiz_questions x
      where x.user_id = f.user_id
        and (f.question = x.text or starts_with(f.question, x.text || E'\n\n'))
   );
