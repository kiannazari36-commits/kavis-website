-- Third question type: fill in the blank ("boşluk doldurma"). Questions are multiple_choice, fill_blank or written;
-- the student chooses which types an exam has. fill_blank / written keep the right answer in quiz_questions.model_answer
-- and the student's text in quiz_answers.written_answer; the server (grade-quiz) judges them.
alter type public.question_kind add value if not exists 'fill_blank';
