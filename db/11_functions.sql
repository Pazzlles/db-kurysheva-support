
-- Лабораторная работа №3. Логика в базе
-- Тема №19: Служба поддержки
-- Файл 11_functions.sql
-- Создание функций для работы с заявками


-- 1. Функция подсчёта комментариев к заявке

-- Функция получает ID заявки и возвращает
-- количество комментариев, оставленных к ней.

-- CREATE FUNCTION создаёт функцию в базе данных.
-- p_ticket_id — параметр, в который передаётся ID заявки.
-- INTEGER означает целое число.
CREATE FUNCTION count_ticket_comments(p_ticket_id INTEGER)

-- RETURNS BIGINT означает, что функция возвращает целое число.
-- Используем BIGINT, потому что COUNT возвращает именно этот тип.
RETURNS BIGINT

-- LANGUAGE sql означает, что тело функции написано на SQL.
LANGUAGE sql

-- AS $$ ... $$ содержит команды, которые выполняет функция.
AS $$
    SELECT COUNT(*)
    FROM comments

    -- Считаем только комментарии к указанной заявке.
    WHERE ticket_id = p_ticket_id;
$$;


-- 2. Бизнес-операция закрытия заявки

-- CREATE OR REPLACE FUNCTION создаёт функцию,
-- а если она уже существует — обновляет её код.
-- Это удобно, потому что мы уже создали эту функцию ранее.

-- Функция принимает номер заявки и меняет её статус
-- на closed (закрыта).

CREATE OR REPLACE FUNCTION close_ticket(p_ticket_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql

AS $$
DECLARE
    -- Переменная для хранения ID изменённой заявки.
    v_ticket_id INTEGER;

BEGIN

    -- UPDATE изменяет данные в таблице tickets.
    -- SET задаёт новое значение столбца status.
    -- WHERE выбирает заявку по её идентификатору.
    -- Дополнительно проверяем, что она ещё не закрыта.
    --
    -- RETURNING получает ID изменённой заявки.
    -- INTO сохраняет этот ID в переменную v_ticket_id.
    --
    -- Сам SQL-запрос записываем без комментариев
    -- между UPDATE, SET, WHERE и RETURNING.
    UPDATE tickets
    SET status = 'closed'
    WHERE id = p_ticket_id
      AND status <> 'closed'
    RETURNING id INTO v_ticket_id;

    -- FOUND показывает, была ли изменена хотя бы одна строка.
    -- Если заявка не существует или уже закрыта,
    -- выводим сообщение об ошибке.
    IF NOT FOUND THEN

        -- RAISE EXCEPTION прерывает выполнение функции.
        -- Вместо % подставляется номер заявки.
        RAISE EXCEPTION
            'Заявка % не найдена или уже закрыта',
            p_ticket_id;

    END IF;

    -- Возвращаем номер закрытой заявки.
    RETURN v_ticket_id;

END;
$$;


-- 3. ★ Функция поиска заявок с фильтрами

-- Позволяет искать заявки по статусу, категории
-- и приоритету.

-- Каждый фильтр необязательный.
-- DEFAULT NULL означает, что параметр можно не передавать.

CREATE FUNCTION search_tickets(
    p_status VARCHAR(20) DEFAULT NULL,
    p_category_id INTEGER DEFAULT NULL,
    p_priority INTEGER DEFAULT NULL
)

-- RETURNS TABLE означает, что функция возвращает таблицу.
-- В скобках перечисляем её столбцы и типы данных.
RETURNS TABLE (
    ticket_id INTEGER,
    title VARCHAR(200),
    status VARCHAR(20),
    priority INTEGER,
    category VARCHAR(100)
)

LANGUAGE sql

AS $$
    SELECT
        t.id,
        t.title,
        t.status,
        t.priority,
        c.name

    FROM tickets t

    -- Получаем название категории заявки.
    JOIN categories c ON c.id = t.category_id

    WHERE
        -- Если p_status равен NULL, статус не проверяем.
        -- Иначе оставляем заявки с указанным статусом.
        (p_status IS NULL OR t.status = p_status)

        -- AND означает, что следующие условия
        -- должны выполняться одновременно.
        AND
        (p_category_id IS NULL OR t.category_id = p_category_id)

        AND
        (p_priority IS NULL OR t.priority = p_priority)

    -- Сортируем найденные заявки по ID.
    ORDER BY t.id;
$$;