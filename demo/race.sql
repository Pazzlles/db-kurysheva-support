-- Бизнес-правило: нельзя закрывать заявку без ответа сотрудника
-- Покажем ситуацию, когда две транзакции по отдельности выполняются успешно, но вместе нарушают это правило:
--    Окно A закрывает заявку
--    Окно B удаляет единственный ответ сотрудника

-- ВАЖНО:
-- [setup], [A], [B], [check], [cleanup] — специальные метки проверяющей программы dbcheck
-- Они определяют порядок выполнения SQL в разных подключениях к PostgreSQL


-- [setup] Создаём отдельную тестовую заявку
-- Сначала удаляем результат предыдущего запуска, если он остался в базе
DELETE FROM tickets
WHERE title = 'race-test-lab4';

-- Создаём заявку со статусом in_progress (в работе
-- Используем существующих клиента, сотрудника и категорию с идентификаторами 1
INSERT INTO tickets (
    client_id,
    employee_id,
    category_id,
    title,
    description,
    status,
    priority
)
VALUES (
    1,
    1,
    1,
    'race-test-lab4',
    'Тестовая заявка для проверки гонки',
    'in_progress',
    2
);

-- Добавляем один комментарий сотрудника. Благодаря этому триггер ЛР №3 разрешит закрыть заявку
INSERT INTO comments (
    ticket_id,
    employee_id,
    message
)
SELECT
    id,
    1,
    'Ответ сотрудника для тестовой заявки'
FROM tickets
WHERE title = 'race-test-lab4';


-- [A] Начинаем транзакцию в первом окне
BEGIN;


-- [A] Закрываем тестовую заявку
-- Триггер ЛР №3 проверяет наличие ответа. Пока ответ существует, закрытие разрешается
UPDATE tickets
SET status = 'closed'
WHERE title = 'race-test-lab4';


-- [B] Начинаем другую транзакцию
BEGIN;


-- [B] Удаляем единственный ответ сотрудника
-- Текущий триггер ЛР №3 не запрещает удаление комментариев из таблицы comments
DELETE FROM comments
WHERE ticket_id = (
    SELECT id
    FROM tickets
    WHERE title = 'race-test-lab4'
)
AND employee_id IS NOT NULL;


-- [B] Сохраняем удаление комментария
COMMIT;


-- [A] Сохраняем закрытие заявки
COMMIT;


-- [check] Проверяем соблюдение бизнес-правила
-- expect: false
-- Внутренний NOT EXISTS ищет закрытую заявку, у которой нет ни одного ответа сотрудника
-- Внешний NOT EXISTS проверяет отсутствие таких неправильных заявок
-- Если получено false, нарушение существует. Для этого сценария false — ожидаемый результат
SELECT NOT EXISTS (  -- NOT EXISTS означает «не существует»
    SELECT 1
    FROM tickets t
    WHERE t.title = 'race-test-lab4'
      AND t.status = 'closed'
      AND NOT EXISTS (
          SELECT 1
          FROM comments c
          WHERE c.ticket_id = t.id
            AND c.employee_id IS NOT NULL
      )
);


-- [cleanup] Удаляем тестовую заявку
-- Комментарий уже удалён в окне B
-- Удаляем созданную для проверки заявку, чтобы не оставлять лишние данные в tickets
DELETE FROM tickets
WHERE title = 'race-test-lab4';