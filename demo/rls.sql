
-- Лабораторная работа №4. Дополнительное задание ★★
-- Проверка Row Level Security (RLS)
--
-- Проверяем, что пользователи видят только свои заметки.
-- Используем роли rls_user_1 и rls_user_2.
--
-- Ожидаемую ошибку доступа выполняем
-- внутри отдельной транзакции.
-- После неё используем ROLLBACK.


-- 1. Подготавливаем тестовые данные.

-- Удаляем заметки предыдущих запусков,
-- чтобы проверка была повторяемой.

DELETE FROM private_notes
WHERE note IN (
    'rls-test-lab4-user1',
    'rls-test-lab4-user2'
);

-- Добавляем две заметки разных пользователей.

INSERT INTO private_notes (owner_name, note)
VALUES
    ('rls_user_1', 'rls-test-lab4-user1'),
    ('rls_user_2', 'rls-test-lab4-user2');


-- 2. Проверяем общее количество заметок.
-- expect: value 2

-- Запрос выполняется с исходными правами подключения.
-- Суперпользователь PostgreSQL обходит обычные
-- ограничения RLS и видит обе записи.

SELECT COUNT(*)
FROM private_notes
WHERE note IN (
    'rls-test-lab4-user1',
    'rls-test-lab4-user2'
);


-- 3. Переключаемся на первого пользователя.

-- SET ROLE изменяет текущую активную роль.
-- Все последующие запросы проверяются с её правами.

SET ROLE rls_user_1;


-- 4. Проверяем количество доступных заметок.
-- expect: value 1

-- Хотя в таблице две заметки,
-- политика RLS разрешает видеть только свою.

SELECT COUNT(*)
FROM private_notes
WHERE note LIKE 'rls-test-lab4-%';


-- 5. Проверяем владельца видимой заметки.
-- expect: true

-- current_user возвращает имя текущей роли.
-- bool_and возвращает true, если все найденные
-- строки удовлетворяют условию.
--
-- Так мы проверяем не только количество,
-- но и правильность выбора заметки.

SELECT bool_and(owner_name = current_user)
FROM private_notes
WHERE note LIKE 'rls-test-lab4-%';


-- 6. Начинаем транзакцию для проверки запрета.

-- Ожидаемая ошибка UPDATE приведёт
-- транзакцию в состояние ошибки.
-- Поэтому после проверки выполним ROLLBACK.

BEGIN;


-- 7. Пытаемся изменить заметку без права UPDATE.
-- expect: error permission

-- Роли rls_user_1 выдано право SELECT,
-- но не выдано право UPDATE.
--
-- PostgreSQL должен отказать в изменении
-- даже собственной заметки пользователя.

UPDATE private_notes
SET note = 'changed'
WHERE note = 'rls-test-lab4-user1';


-- 8. Отменяем ошибочную транзакцию.

-- ROLLBACK завершает транзакцию.
-- Роль, установленная до BEGIN, сохраняется.

ROLLBACK;


-- 9. Возвращаем исходную роль.

RESET ROLE;


-- 10. Переключаемся на второго пользователя.

SET ROLE rls_user_2;


-- 11. Проверяем количество доступных заметок.
-- expect: value 1

-- Второй пользователь видит только свою запись.
-- Заметка первого пользователя скрыта политикой.

SELECT COUNT(*)
FROM private_notes
WHERE note LIKE 'rls-test-lab4-%';


-- 12. Проверяем владельца заметки.
-- expect: true

-- Все видимые строки должны принадлежать
-- текущему пользователю rls_user_2.

SELECT bool_and(owner_name = current_user)
FROM private_notes
WHERE note LIKE 'rls-test-lab4-%';


-- 13. Возвращаем исходную роль.

RESET ROLE;


-- 14. Проверяем, что обе заметки сохранились.
-- expect: value 2

-- Ограничение RLS только скрывает чужие строки.
-- Оно не удаляет записи из таблицы.

SELECT COUNT(*)
FROM private_notes
WHERE note IN (
    'rls-test-lab4-user1',
    'rls-test-lab4-user2'
);


-- 15. Удаляем тестовые данные.
-- expect: rows 2

-- Очистку выполняем с исходными правами.
-- Удаляем только две специально созданные заметки.

DELETE FROM private_notes
WHERE note IN (
    'rls-test-lab4-user1',
    'rls-test-lab4-user2'
);