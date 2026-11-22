
-- ЛР №4. Дополнительное задание ★
-- Уровень изоляции READ COMMITTED
--
-- Два подключения одновременно работают
-- с одной тестовой заявкой.
--
-- Окно A сначала видит приоритет 2.
-- Окно B изменяет его на 3.
-- После COMMIT окна B окно A увидит 3.
--
-- Такое изменение результата двух чтений
-- называется неповторяющимся чтением.


-- [setup] Создаём тестовую заявку с приоритетом 2.

DELETE FROM tickets
WHERE title = 'isolation-rc-test';

INSERT INTO tickets (
    client_id, employee_id, category_id,
    title, description, status, priority
)
VALUES (
    1, 1, 1,
    'isolation-rc-test',
    'Проверка READ COMMITTED',
    'in_progress', 2
);


-- [A] Начинаем транзакцию с уровнем READ COMMITTED.

-- Этот уровень используется в PostgreSQL
-- по умолчанию.
-- Каждый новый SELECT получает актуальный
-- снимок зафиксированных данных.

BEGIN ISOLATION LEVEL READ COMMITTED;


-- [A] Первый раз читаем приоритет.
-- expect: value 2

SELECT priority
FROM tickets
WHERE title = 'isolation-rc-test';


-- [B] Начинаем вторую транзакцию.
BEGIN;


-- [B] Меняем приоритет с 2 на 3.

UPDATE tickets
SET priority = 3
WHERE title = 'isolation-rc-test';


-- [B] Сохраняем изменение.
COMMIT;


-- [A] Повторно читаем приоритет.
-- expect: value 3

-- Несмотря на то что окно A
-- не завершало свою транзакцию,
-- новый SELECT видит изменение окна B.

SELECT priority
FROM tickets
WHERE title = 'isolation-rc-test';


-- [A] Завершаем транзакцию.
COMMIT;


-- [check] Проверяем сохранённое значение.
-- expect: true

SELECT EXISTS (
    SELECT 1
    FROM tickets
    WHERE title = 'isolation-rc-test'
      AND priority = 3
);


-- [cleanup] Удаляем тестовую заявку.

DELETE FROM tickets
WHERE title = 'isolation-rc-test';