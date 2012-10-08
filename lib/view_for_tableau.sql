create view _answers as select
  r.id AS response_id,
  r.reviewed AS is_reviewed,
  f.name AS form_name,
  ft.name AS form_type,
  q.code AS question_code,
  qtr.str AS question_name,
  qt.name AS question_type,
  u.name AS observer_name,
  a.id AS answer_id,
  a.value AS answer_value,
  a.date_value AS date_value,
  IFNULL(aotr.str, cotr.str) AS choice_name,
  IFNULL(ao.value, co.value) AS choice_value,
  os.name AS option_set
from answers a
  left join options ao on a.option_id = ao.id
    left join translations aotr on (aotr.obj_id = ao.id and aotr.fld = 'name' and aotr.class_name = 'Option'
      and aotr.language = 'eng')
  left join choices c on c.answer_id = a.id
    left join options co on c.option_id = co.id
      left join translations cotr on (cotr.obj_id = co.id and cotr.fld = 'name' and cotr.class_name = 'Option'
        and cotr.language = 'eng')
  join responses r on a.response_id = r.id
    join users u on r.user_id = u.id
    join forms f on r.form_id = f.id
      join form_types ft on f.form_type_id = ft.id
  join questionings qing on a.questioning_id = qing.id
    join questions q on qing.question_id = q.id
      join question_types qt on q.question_type_id = qt.id
      left join option_sets os on q.option_set_id = os.id
        join translations qtr on (qtr.obj_id = q.id and qtr.fld = 'name' and qtr.class_name = 'Question'
          and qtr.language = 'eng');