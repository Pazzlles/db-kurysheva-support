
-- Лабораторная работа №3. Логика в базе
-- Тема №19: Служба поддержки
-- Файл demo/lab3.sql
-- Проверка представлений, функций и триггеров


-- 1. Какие данные о заявках показывает первое представление?
-- expect: rows

-- VIEW позволяет получить данные из нескольких таблиц
-- без повторного написания соединений JOIN.
SELECT *
FROM v_ticket_info
ORDER BY id
LIMIT 10;


-- 2. Сколько заявок назначено каждому сотруднику?
-- expect: rows

-- Второе представление подсчитывает общее количество
-- заявок сотрудников и количество закрытых заявок.
SELECT *
FROM v_employee_stats
ORDER BY id;


-- 3. Сколько комментариев оставлено к заявке №1?
-- expect: value 2

-- Функция получает ID заявки и возвращает количество
-- её комментариев с помощью COUNT(*).
SELECT count_ticket_comments(1);


-- 4. ★ Какие новые заявки имеют приоритет 2?
-- expect: rows

-- Функция search_tickets позволяет искать заявки
-- по статусу, категории и приоритету.

-- Первый параметр 'new' означает новые заявки.
-- Второй параметр NULL означает, что категория может быть любой.
-- Третий параметр 2 означает средний приоритет.
-- LIMIT 10 ограничивает результат первыми десятью строками.
SELECT *
FROM search_tickets('new', NULL, 2)
LIMIT 10;


-- 5. ★ Как выглядит отчёт по категориям и статусам?
-- expect: rows

-- Материализованное представление хранит результат
-- запроса до следующего обновления.
SELECT *
FROM mv_ticket_report
ORDER BY category;


-- 6. ★ Как обновить материализованное представление?
-- expect: rows

-- REFRESH заново рассчитывает сохранённый отчёт.
REFRESH MATERIALIZED VIEW mv_ticket_report;

-- Проверяем, что после обновления есть данные.
SELECT *
FROM mv_ticket_report
ORDER BY category;


-- 7. Можно ли закрыть заявку №1, если сотрудник ответил?
-- expect: rows

-- BEGIN начинает транзакцию.
BEGIN;

-- Показываем статус до изменения.
SELECT id, status
FROM tickets
WHERE id = 1;

-- Бизнес-операция закрывает заявку одной командой.
SELECT close_ticket(1);

-- Проверяем новый статус.
SELECT id, status
FROM tickets
WHERE id = 1;

-- Отменяем изменение, чтобы сохранить исходные данные.
ROLLBACK;


-- 8. Можно ли закрыть заявку №2 без ответа сотрудника?
-- expect: error "без ответа сотрудника"

-- У заявки №2 нет комментария сотрудника.
-- BEFORE-триггер запрещает менять её статус на closed.
-- Ошибка здесь является ожидаемым результатом.
SELECT close_ticket(2);


-- 9. Можно ли обойти правило обычным UPDATE?
-- expect: error "без ответа сотрудника"

-- Даже если не использовать функцию close_ticket,
-- триггер всё равно проверяет бизнес-правило.
UPDATE tickets
SET status = 'closed'
WHERE id = 2;


-- 10. Обновляется ли дата изменения заявки?
-- expect: true

BEGIN;

-- Изменяем приоритет заявки №1.
-- BEFORE-триггер автоматически обновляет updated_at.
UPDATE tickets
SET priority = 3
WHERE id = 1;

-- Проверяем, что дата изменения стала позднее
-- первоначальной даты создания заявки.
SELECT updated_at > created_at
FROM tickets
WHERE id = 1;

-- Отменяем изменение.
ROLLBACK;


-- 11. ★★ Сохраняются ли старые и новые значения?
-- expect: rows

BEGIN;

-- Меняем приоритет заявки с 2 на 3.
UPDATE tickets
SET priority = 3
WHERE id = 1;

-- AFTER-триггер сохраняет обе версии в ticket_history.
-- Оператор ->> извлекает значение из JSONB как текст.
SELECT
    ticket_id,
    operation,
    old_data->>'priority' AS old_priority,
    new_data->>'priority' AS new_priority,
    changed_by,
    changed_at
FROM ticket_history
WHERE ticket_id = 1
ORDER BY id DESC
LIMIT 1;

-- Отменяем изменение и запись истории.
ROLLBACK;


-- 12. ★★ Сохраняется ли история добавления и удаления?
-- expect: rows

BEGIN;

-- Создаём временную тестовую заявку.
INSERT INTO tickets (
    client_id,
    category_id,
    title,
    description
)
VALUES (
    1,
    1,
    'Проверка истории ЛР3',
    'Тестовая заявка для проверки журнала'
);

-- Удаляем созданную заявку.
DELETE FROM tickets
WHERE title = 'Проверка истории ЛР3'
  AND description = 'Тестовая заявка для проверки журнала';

-- Проверяем, что журнал содержит INSERT и DELETE.
SELECT
    operation,
    old_data->>'title' AS old_title,
    new_data->>'title' AS new_title
FROM ticket_history
WHERE old_data->>'title' = 'Проверка истории ЛР3'
   OR new_data->>'title' = 'Проверка истории ЛР3'
ORDER BY id;

-- Все тестовые изменения отменяются.
ROLLBACK;


-- 13. ★★ Можно ли получить состояние заявки на дату?
-- expect: rows

BEGIN;

-- Меняем приоритет заявки.
UPDATE tickets
SET priority = 3
WHERE id = 1;

-- changed_at — время записанного изменения.
-- Передаём в функцию момент непосредственно до него
-- и момент, когда изменение уже произошло.
--
-- Функция возвращает JSONB с состоянием заявки.
-- ->> 'priority' извлекает из результата приоритет.
SELECT
    ticket_state_at(
        1,
        h.changed_at - INTERVAL '1 microsecond'
    )->>'priority' AS priority_before,

    ticket_state_at(
        1,
        h.changed_at
    )->>'priority' AS priority_after

FROM ticket_history h
WHERE h.ticket_id = 1
  AND h.operation = 'UPDATE'
ORDER BY h.id DESC
LIMIT 1;

-- Возвращаем базу в исходное состояние.
ROLLBACK;


-- 14. ★ Обновляется ли отчёт после изменения данных?
-- expect: rows

BEGIN;

-- У заявки №1 есть ответ сотрудника.
-- Поэтому её можно временно закрыть.
SELECT close_ticket(1);

-- Пересчитываем материализованное представление.
REFRESH MATERIALIZED VIEW mv_ticket_report;

-- Проверяем статистику категории «Авторизация».
-- Закрытых заявок должно стать на одну больше.
SELECT category, total, closed_count
FROM mv_ticket_report
WHERE category = 'Авторизация';

-- Отменяем изменение заявки и обновление отчёта.
ROLLBACK;