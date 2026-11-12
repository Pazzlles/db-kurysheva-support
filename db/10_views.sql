
-- Лабораторная работа №3. Логика в базе
-- Тема №19: Служба поддержки
-- Файл 10_views.sql
-- Создание представлений для работы с заявками


-- 1. Представление с подробной информацией о заявках

-- VIEW (представление) — это сохранённый SQL-запрос.
-- Оно позволяет получать данные из нескольких таблиц
-- без повторного написания JOIN при каждом обращении.

-- CREATE VIEW создаёт представление с указанным названием.
CREATE VIEW v_ticket_info AS

-- Выбираем поля, которые хотим видеть в результате.
SELECT
    t.id,
    t.title,
    c.name AS client,
    e.name AS employee,
    cat.name AS category,
    t.status,
    t.priority,
    t.created_at

-- Основная таблица содержит информацию о заявках.
FROM tickets t

-- JOIN добавляет имя клиента по его идентификатору.
JOIN clients c ON c.id = t.client_id

-- LEFT JOIN сохраняет заявку даже в том случае,
-- если сотрудник для её обработки ещё не назначен.
-- Тогда в столбце employee будет NULL.
LEFT JOIN employees e ON e.id = t.employee_id

-- Добавляем название категории заявки.
JOIN categories cat ON cat.id = t.category_id;


-- 2. Представление со статистикой по сотрудникам

-- Это представление показывает количество заявок,
-- назначенных каждому сотруднику.

CREATE VIEW v_employee_stats AS

SELECT
    e.id,
    e.name AS employee,

    -- COUNT(t.id) считает заявки, связанные с сотрудником.
    -- Если заявок нет, результат будет равен 0.
    COUNT(t.id) AS ticket_count,

    -- FILTER позволяет считать только заявки,
    -- которые соответствуют определённому условию.
    -- Здесь подсчитываем заявки со статусом closed.
    COUNT(t.id) FILTER (
        WHERE t.status = 'closed'
    ) AS closed_count

-- Начинаем с таблицы сотрудников.
FROM employees e

-- LEFT JOIN нужен, чтобы показать всех сотрудников,
-- даже если на некоторых из них нет заявок.
LEFT JOIN tickets t ON t.employee_id = e.id

-- GROUP BY объединяет заявки каждого сотрудника.
GROUP BY e.id, e.name;


-- 3. ★ Материализованное представление с отчётом

-- MATERIALIZED VIEW, в отличие от обычного VIEW,
-- сохраняет результат запроса в базе данных.
-- Чтобы обновить сохранённые данные,
-- используется команда REFRESH MATERIALIZED VIEW.

-- Отчёт показывает количество заявок по категориям
-- и их статусам.

CREATE MATERIALIZED VIEW mv_ticket_report AS

SELECT
    c.name AS category,

    -- Считаем общее количество заявок категории.
    COUNT(t.id) AS total,

    -- Отдельно подсчитываем заявки каждого статуса.
    COUNT(t.id) FILTER (
        WHERE t.status = 'new'
    ) AS new_count,

    COUNT(t.id) FILTER (
        WHERE t.status = 'in_progress'
    ) AS work_count,

    COUNT(t.id) FILTER (
        WHERE t.status = 'closed'
    ) AS closed_count

FROM categories c

-- LEFT JOIN сохраняет категории без заявок.
LEFT JOIN tickets t ON t.category_id = c.id

-- Объединяем строки по категориям.
GROUP BY c.id, c.name;