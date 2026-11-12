-- Лабораторная работа №2. Запросы к базе службы поддержки

-- 1. Какие клиенты создали заявки и как называются эти заявки?
-- expect: rows
SELECT c.name, t.title
FROM tickets t
-- JOIN соединяет заявки с клиентами по их идентификаторам
JOIN clients c ON c.id = t.client_id
-- Сортируем по ID заявки и выводим первые 10 строк
ORDER BY t.id
LIMIT 10;

-- 2. Какие сотрудники назначены на заявки?
-- expect: rows
SELECT e.name, t.title, t.status
FROM tickets t
-- JOIN оставляет заявки, у которых есть связанный сотрудник
JOIN employees e ON e.id = t.employee_id
ORDER BY t.id
LIMIT 10;

-- 3. Какие заявки относятся к категориям и кто их создал?
-- expect: rows
-- AS задаёт названия столбцов в результате запроса
SELECT t.title, c.name AS client, cat.name AS category
FROM tickets t
-- Два JOIN позволяют получить клиента и категорию каждой заявки
JOIN clients c ON c.id = t.client_id
JOIN categories cat ON cat.id = t.category_id
ORDER BY t.id
LIMIT 10;

-- 4. Какие теги назначены первым заявкам?
-- expect: rows
-- ticket_tags связывает заявки и теги (связь многие ко многим)
SELECT t.title, tg.name AS tag
FROM ticket_tags tt
JOIN tickets t ON t.id = tt.ticket_id
JOIN tags tg ON tg.id = tt.tag_id
-- Сортируем по ID заявки, затем по названию тега
ORDER BY t.id, tg.name
LIMIT 15;

-- 5. Сколько заявок создал каждый клиент?
-- expect: rows
-- COUNT(t.id) не учитывает NULL, поэтому клиент без заявок получит 0
SELECT c.name, COUNT(t.id) AS ticket_count
FROM clients c
-- LEFT JOIN сохраняет даже клиентов, у которых нет заявок
LEFT JOIN tickets t ON t.client_id = c.id
-- GROUP BY объединяет записи по клиентам для подсчёта заявок
GROUP BY c.id, c.name
ORDER BY c.id;

-- 6. В каких категориях больше десяти заявок?
-- expect: rows
SELECT c.name, COUNT(t.id) AS ticket_count
FROM categories c
JOIN tickets t ON t.category_id = c.id
GROUP BY c.id, c.name
-- HAVING фильтрует группы после подсчёта количества заявок
HAVING COUNT(t.id) > 10
-- DESC сортирует количество заявок по убыванию
ORDER BY ticket_count DESC, c.name;

-- 7. Какие сотрудники ещё не оставляли комментариев?
-- expect: rows
SELECT e.name
FROM employees e
-- LEFT JOIN сохраняет всех сотрудников, даже если комментариев нет
LEFT JOIN comments c ON c.employee_id = e.id
-- IS NULL выбирает сотрудников, для которых комментарии не найдены
WHERE c.id IS NULL
ORDER BY e.id;

-- 8. Какие клиенты имеют хотя бы одну заявку с высоким приоритетом?
-- expect: rows
-- IN проверяет наличие ID клиента среди результатов подзапроса
SELECT c.name
FROM clients c
WHERE c.id IN (
    SELECT t.client_id
    FROM tickets t
    -- Приоритет 3 соответствует высокому приоритету
    WHERE t.priority = 3
)
ORDER BY c.id;

-- 9. К каким заявкам сотрудники уже написали ответы?
-- expect: rows
-- EXISTS проверяет существование хотя бы одного подходящего комментария
SELECT t.id, t.title
FROM tickets t
WHERE EXISTS (
    -- EXISTS проверяет, есть ли хотя бы одна подходящая строка, поэтому в SELECT достаточно указать 1
    SELECT 1
    FROM comments c
    -- IS NOT NULL означает, что комментарий оставил сотрудник
    WHERE c.ticket_id = t.id AND c.employee_id IS NOT NULL
)
ORDER BY t.id;

-- 10. Сколько тестовых заявок до и после добавления?
-- expect: rows
-- BEGIN начинает транзакцию, ROLLBACK отменяет изменения
BEGIN;
-- Считаем количество тестовых заявок до вставки
SELECT COUNT(*) AS before
FROM tickets
WHERE title = 'Проверка вставки ЛР2';
-- INSERT добавляет новую запись в таблицу
INSERT INTO tickets (client_id, category_id, title, description)
VALUES (1, 1, 'Проверка вставки ЛР2', 'Тестовая заявка для второй лабораторной');
-- Проверяем количество после вставки
SELECT COUNT(*) AS after
FROM tickets
WHERE title = 'Проверка вставки ЛР2';
ROLLBACK;

-- 11. Как меняется приоритет первой заявки с 2 на 3?
-- expect: rows
BEGIN;
SELECT id, title, priority
FROM tickets
WHERE id = 1;
-- UPDATE меняет приоритет только в том случае, если он равен 2
UPDATE tickets
SET priority = 3
WHERE id = 1 AND priority = 2;
-- Проверяем результат изменения
SELECT id, title, priority
FROM tickets
WHERE id = 1;
ROLLBACK;

-- 12. Как удалить одну сгенерированную заявку и проверить результат?
-- expect: rows
BEGIN;
SELECT id, title
FROM tickets
WHERE title = 'Заявка 1000';
-- DELETE удаляет строки, подходящие под оба условия
DELETE FROM tickets
WHERE title = 'Заявка 1000'
  AND description = 'Тестовое обращение 1000';
-- Считаем оставшиеся заявки с таким названием
SELECT COUNT(*) AS remaining
FROM tickets
WHERE title = 'Заявка 1000';
ROLLBACK;

-- 13. ★ Часть 1: CTE и топ-3 через ROW_NUMBER(). Какие три заявки самые приоритетные в каждой категории?
-- expect: rows
-- Оконная функция нумерует заявки, не объединяя их в одну строку, в отличие от группировки
-- WITH создаёт временный именованный результат (CTE).
WITH numbered AS (
    SELECT c.name AS category, t.title, t.priority,
           -- ROW_NUMBER нумерует заявки отдельно в каждой категории
           ROW_NUMBER() OVER (
               -- PARTITION BY разделяет заявки по категориям
               PARTITION BY t.category_id
               -- Сначала высокий приоритет, при равенстве — меньший ID
               ORDER BY t.priority DESC, t.id
           ) AS num
    FROM tickets t
    JOIN categories c ON c.id = t.category_id
)
SELECT category, title, priority, num
FROM numbered
-- Оставляем только первые три заявки каждой категории
WHERE num <= 3
ORDER BY category, num;

-- 14. ★ Часть 2: оконная функция LAG(). Как менялось количество заявок по месяцам?
-- expect: rows
BEGIN;
SELECT COUNT(*) AS before
FROM tickets
WHERE description = 'Проверка динамики';
-- Добавляем тестовые заявки за два разных месяца
INSERT INTO tickets (client_id, category_id, title, description, created_at)
VALUES
(1, 1, 'Тест за август', 'Проверка динамики', '2026-08-15'),
(1, 1, 'Тест за сентябрь', 'Проверка динамики', '2026-09-15');
SELECT COUNT(*) AS after
FROM tickets
WHERE description = 'Проверка динамики';
-- Первый CTE подсчитывает заявки по месяцам
WITH months AS (
    -- date_trunc приводит дату к началу месяца.
    SELECT date_trunc('month', created_at) AS month,
           COUNT(*) AS total
    FROM tickets
    GROUP BY date_trunc('month', created_at)
),
-- Второй CTE сравнивает месяцы между собой
changes AS (
    SELECT month, total,
           -- LAG берёт значение из предыдущей строки месячной статистики
           LAG(total) OVER (ORDER BY month) AS previous
    FROM months
)
SELECT month::date, total, previous,
       -- NULLIF предотвращает деление на ноль
       -- ROUND округляет процент изменения до одного знака
       -- 100.0 позволяет получить результат с дробной частью
       ROUND(100.0 * (total - previous) / NULLIF(previous, 0), 1) AS change_percent
FROM changes
ORDER BY month;
-- Отменяем добавление тестовых заявок
ROLLBACK;

-- 15. ★★ Сводка с условными подсчётами. Сколько заявок каждого статуса было за последние шесть месяцев?
-- expect: rows
-- WITH RECURSIVE создаёт последовательность из шести месяцев
WITH RECURSIVE months AS (
    -- Начинаем с первого дня текущего месяца
    SELECT date_trunc('month', CURRENT_DATE) AS month
    -- UNION ALL объединяет результаты запросов, сохраняя повторяющиеся строки
    UNION ALL
    -- На каждом шаге переходим на месяц назад
    SELECT month - INTERVAL '1 month'
    FROM months
    WHERE month > date_trunc('month', CURRENT_DATE) - INTERVAL '5 months'
)
SELECT m.month::date AS month,
       COUNT(t.id) AS total,
       -- FILTER подсчитывает заявки только с указанным статусом
       COUNT(*) FILTER (WHERE t.status = 'new') AS new_count,
       COUNT(*) FILTER (WHERE t.status = 'in_progress') AS work_count,
       COUNT(*) FILTER (WHERE t.status = 'closed') AS closed_count,
       -- Считаем процент закрытых заявок за каждый месяц
       ROUND(
           -- NULLIF заменяет нулевой знаменатель на NULL, чтобы избежать деления на ноль
           100.0 * COUNT(*) FILTER (WHERE t.status = 'closed')
           / NULLIF(COUNT(t.id), 0), 1
       ) AS closed_percent
FROM months m
-- LEFT JOIN позволяет показать даже месяцы без заявок.
LEFT JOIN tickets t ON date_trunc('month', t.created_at) = m.month
GROUP BY m.month
ORDER BY m.month;