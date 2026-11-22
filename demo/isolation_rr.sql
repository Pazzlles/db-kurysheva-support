
-- ЛР №4. Дополнительное задание ★
-- Уровень изоляции REPEATABLE READ
--
-- Повторяем аналогичный эксперимент.
--
-- Окно A сначала видит приоритет 2.
-- Окно B меняет его на 3 и сохраняет изменение.
-- Но окно A продолжает видеть приоритет 2
-- до завершения своей транзакции.


-- [setup] Создаём тестовую заявку.

DELETE FROM tickets
WHERE title = 'isolation-rr-test';

INSERT INTO tickets (
    client_id, employee_id, category_id,
    title, description, status, priority
)
VALUES (
    1, 1, 1,
    'isolation-rr-test',
    'Проверка REPEATABLE READ',
    'in_progress', 2
);


-- [A] Начинаем транзакцию REPEATABLE READ.

-- PostgreSQL сохраняет снимок данных
-- для всей транзакции.
-- Повторные SELECT видят тот же снимок.

BEGIN ISOLATION LEVEL REPEATABLE READ;


-- [A] Первый раз читаем приоритет.
-- expect: value 2

-- Здесь формируется снимок данных
-- для дальнейших чтений этой транзакции.

SELECT priority
FROM tickets
WHERE title = 'isolation-rr-test';


-- [B] Начинаем вторую транзакцию.
BEGIN;


-- [B] Меняем приоритет заявки.

UPDATE tickets
SET priority = 3
WHERE title = 'isolation-rr-test';


-- [B] Сохраняем изменение.
COMMIT;


-- [A] Повторно читаем приоритет.
-- expect: value 2

-- Окно B уже сохранило значение 3.
-- Но окно A всё ещё видит снимок,
-- полученный при первом чтении.

SELECT priority
FROM tickets
WHERE title = 'isolation-rr-test';


-- [A] Завершаем транзакцию.
COMMIT;


-- [check] Проверяем значение после завершения.
-- expect: true

-- В новом подключении уже видно
-- окончательно сохранённое значение 3.

SELECT EXISTS (
    SELECT 1
    FROM tickets
    WHERE title = 'isolation-rr-test'
      AND priority = 3
);


-- [cleanup] Удаляем тестовую заявку.

DELETE FROM tickets
WHERE title = 'isolation-rr-test';