-- Исправление гонки данных
-- Повторяем ситуацию из race.sql:
--    окно A закрывает заявку
--    окно B пытается удалить ответ сотрудника
-- Отличие: операции выполняются через защищённые функции
-- Ожидаемый результат:
--    окно B ждёт блокировку заявки
--    после завершения окна A удаление не выполняется
--    заявка остаётся закрытой с ответом сотрудника

-- [setup] Подготавливаем отдельную тестовую заявку
-- Удаляем остатки предыдущего запуска
DELETE FROM tickets
WHERE title = 'race-fixed-test-lab4';

-- Создаём заявку в работе
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
    'race-fixed-test-lab4',
    'Проверка защищённых операций',
    'in_progress',
    2
);

-- Добавляем ответ сотрудника
INSERT INTO comments (
    ticket_id,
    employee_id,
    message
)
SELECT
    id,
    1,
    'Ответ сотрудника для проверки блокировки'
FROM tickets
WHERE title = 'race-fixed-test-lab4';


-- [A] Начинаем первую транзакцию
BEGIN;


-- [A] Закрываем заявку через защищённую функцию
-- Внутренний UPDATE блокирует строку tickets
-- Блокировка сохраняется до COMMIT
SELECT safe_close_ticket(id)  -- safe_close_ticket использует функцию из ЛР №3
FROM tickets
WHERE title = 'race-fixed-test-lab4';


-- [B] Начинаем вторую транзакцию
BEGIN;


-- [B] Пытаемся удалить ответ сотрудника
-- expect: blocked
-- Функция пытается заблокировать ту же заявку через SELECT ... FOR UPDATE
-- Пока окно A не завершило транзакцию, окно B должно ждать освобождения блокировки
SELECT safe_remove_employee_reply(c.id)
FROM comments c
JOIN tickets t ON t.id = c.ticket_id
WHERE t.title = 'race-fixed-test-lab4'
  AND c.employee_id IS NOT NULL;


-- [A] Завершаем закрытие заявки
-- Теперь блокировка tickets освобождается
COMMIT;


-- [B] Завершаем вторую транзакцию
-- После ожидания функция увидит статус closed. Она вернёт false и не удалит комментарий
COMMIT;


-- [check] Проверяем, что бизнес-правило соблюдено
-- expect: true
-- Проверяем наличие закрытой тестовой заявки, для которой сохранился ответ сотрудника
-- Если ответ сохранился, результат будет true
SELECT EXISTS (  -- EXISTS возвращает true, если найдена хотя бы одна строка, подходящая под условие
    SELECT 1
    FROM tickets t
    WHERE t.title = 'race-fixed-test-lab4'
      AND t.status = 'closed'
      AND EXISTS (  -- Внутренний EXISTS проверяет, что у заявки есть комментарий, оставленный сотрудником
          SELECT 1
          FROM comments c
          WHERE c.ticket_id = t.id
            AND c.employee_id IS NOT NULL
      )
);


-- [cleanup] Удаляем тестовые данные
-- Связанные комментарии удалятся автоматически благодаря ON DELETE CASCADE из ЛР №1
DELETE FROM tickets
WHERE title = 'race-fixed-test-lab4';