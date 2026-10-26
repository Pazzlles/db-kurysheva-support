-- Лабораторная работа №2. Запросы к базе службы поддержки

-- 1. Какие клиенты создали заявки и как называются эти заявки?
-- expect: rows
SELECT c.name, t.title
FROM tickets t
JOIN clients c ON c.id = t.client_id
ORDER BY t.id
LIMIT 10;

-- 2. Какие сотрудники назначены на заявки?
-- expect: rows
SELECT e.name, t.title, t.status
FROM tickets t
JOIN employees e ON e.id = t.employee_id
ORDER BY t.id
LIMIT 10;

-- 3. Какие заявки относятся к категориям и кто их создал?
-- expect: rows
SELECT t.title, c.name AS client, cat.name AS category
FROM tickets t
JOIN clients c ON c.id = t.client_id
JOIN categories cat ON cat.id = t.category_id
ORDER BY t.id
LIMIT 10;

-- 4. Какие теги назначены первым заявкам?
-- expect: rows
SELECT t.title, tg.name AS tag
FROM ticket_tags tt
JOIN tickets t ON t.id = tt.ticket_id
JOIN tags tg ON tg.id = tt.tag_id
ORDER BY t.id, tg.name
LIMIT 15;

-- 5. Сколько заявок создал каждый клиент?
-- expect: rows
SELECT c.name, COUNT(t.id) AS ticket_count
FROM clients c
LEFT JOIN tickets t ON t.client_id = c.id
GROUP BY c.id, c.name
ORDER BY c.id;

-- 6. В каких категориях больше десяти заявок?
-- expect: rows
SELECT c.name, COUNT(t.id) AS ticket_count
FROM categories c
JOIN tickets t ON t.category_id = c.id
GROUP BY c.id, c.name
HAVING COUNT(t.id) > 10
ORDER BY ticket_count DESC, c.name;

-- 7. Какие сотрудники ещё не оставляли комментариев?
-- expect: rows
SELECT e.name
FROM employees e
LEFT JOIN comments c ON c.employee_id = e.id
WHERE c.id IS NULL
ORDER BY e.id;

-- 8. Какие клиенты имеют хотя бы одну заявку с высоким приоритетом?
-- expect: rows
SELECT c.name
FROM clients c
WHERE c.id IN (
    SELECT t.client_id
    FROM tickets t
    WHERE t.priority = 3
)
ORDER BY c.id;

-- 9. К каким заявкам сотрудники уже написали ответы?
-- expect: rows
SELECT t.id, t.title
FROM tickets t
WHERE EXISTS (
    SELECT 1
    FROM comments c
    WHERE c.ticket_id = t.id AND c.employee_id IS NOT NULL
)
ORDER BY t.id;

-- 10. Как выглядит новая заявка до и после добавления?
-- expect: rows
BEGIN;
SELECT COUNT(*) AS before FROM tickets WHERE title = 'Проверка вставки ЛР2';
INSERT INTO tickets (client_id, category_id, title, description)
VALUES (1, 1, 'Проверка вставки ЛР2', 'Тестовая заявка для второй лабораторной');
SELECT id, title, status, priority
FROM tickets
WHERE title = 'Проверка вставки ЛР2';
ROLLBACK;

-- 11. Как меняется приоритет первой заявки с 2 на 3?
-- expect: rows
BEGIN;
SELECT id, title, priority FROM tickets WHERE id = 1;
UPDATE tickets SET priority = 3 WHERE id = 1 AND priority = 2;
SELECT id, title, priority FROM tickets WHERE id = 1;
ROLLBACK;

-- 12. Как удалить одну сгенерированную заявку и проверить результат?
-- expect: rows
BEGIN;
SELECT id, title FROM tickets WHERE title = 'Заявка 1000';
DELETE FROM tickets
WHERE title = 'Заявка 1000' AND description = 'Тестовое обращение 1000';
SELECT COUNT(*) AS remaining FROM tickets WHERE title = 'Заявка 1000';
ROLLBACK;

-- 13. ★ Какие три заявки самые приоритетные в каждой категории?
-- expect: rows
WITH numbered AS (
    SELECT c.name AS category, t.title, t.priority,
           ROW_NUMBER() OVER (
               PARTITION BY t.category_id
               ORDER BY t.priority DESC, t.id
           ) AS num
    FROM tickets t
    JOIN categories c ON c.id = t.category_id
)
SELECT category, title, priority, num
FROM numbered
WHERE num <= 3
ORDER BY category, num;

-- 14. ★ Как накапливается сумма приоритетов первых десяти заявок?
-- expect: rows
SELECT id, priority,
       SUM(priority) OVER (ORDER BY id) AS total_priority
FROM tickets
ORDER BY id
LIMIT 10;

-- 15. ★★ Сколько заявок каждого статуса в категории и какова доля закрытых?
-- expect: rows
SELECT c.name AS category,
       COUNT(*) AS total,
       COUNT(*) FILTER (WHERE t.status = 'new') AS new_count,
       COUNT(*) FILTER (WHERE t.status = 'in_progress') AS work_count,
       COUNT(*) FILTER (WHERE t.status = 'closed') AS closed_count,
       ROUND(100.0 * COUNT(*) FILTER (WHERE t.status = 'closed')
             / COUNT(*), 1) AS closed_percent
FROM tickets t
JOIN categories c ON c.id = t.category_id
GROUP BY c.id, c.name
ORDER BY c.id;
