-- Добавляем новые функции, не меняя код ЛР №3
-- Для устранения гонки обе операции должны согласованно работать с одной строкой tickets
-- Закрытие заявки блокирует её строку через UPDATE
-- Удаление ответа будет блокировать ту же строку с помощью SELECT ... FOR UPDATE


-- 1. Защищённая функция закрытия заявки
-- Эта функция использует close_ticket() из ЛР №3 с правами своего владельца, а не вызывающего пользователя
-- Это понадобится при настройке роли app_writer
CREATE OR REPLACE FUNCTION safe_close_ticket(
    p_ticket_id INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER  -- означает, что функция выполняется
SET search_path = public, pg_temp  -- search_path ограничивает поиск объектов схемой public и временной схемой pg_temp

AS $$
BEGIN
    -- Вызываем существующую бизнес-операцию ЛР №3. Она изменяет статус заявки на closed
    -- UPDATE блокирует изменяемую строку tickets до завершения транзакции
    -- Триггер ЛР №3 проверяет ответ сотрудника
    RETURN close_ticket(p_ticket_id);

END;
$$;


-- 2. Защищённая функция удаления ответа сотрудника
-- Принимает номер комментария. Возвращает BOOLEAN — логическое значение:
--    true  — комментарий удалён
--    false — удаление не выполнено
-- Если заявка уже закрыта, не удаляем её ответ сотрудника
CREATE OR REPLACE FUNCTION safe_remove_employee_reply(
    p_comment_id INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp

AS $$
DECLARE

    v_ticket_id INTEGER;  -- Номер заявки, к которой относится комментарий

    v_status VARCHAR(20);  -- Текущий статус этой заявки.

BEGIN

    -- 1. Находим комментарий сотрудника
    SELECT c.ticket_id
    INTO v_ticket_id  -- INTO записывает результат SELECT в переменную
    FROM comments c
    WHERE c.id = p_comment_id
      AND c.employee_id IS NOT NULL;  -- employee_id IS NOT NULL означает, что комментарий оставлен сотрудником

    -- Если подходящего комментария нет, удалять нечего
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;


    -- 2. Блокируем связанную заявку.
    -- Если другая транзакция уже изменяет заявку, наша функция будет ждать её завершения
    SELECT t.status
    INTO v_status
    FROM tickets t
    WHERE t.id = v_ticket_id
    FOR UPDATE;  -- не изменяет строку само по себе. Оно устанавливает блокировку

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;


    -- 3. Проверяем статус после получения блокировки.
    -- Если заявка закрыта, удалять ответ нельзя. Возвращаем false без выполнения DELETE.
    IF v_status = 'closed' THEN
        RETURN FALSE;
    END IF;


    -- 4. Удаляем комментарий.
    -- До конца текущей транзакции строка заявки остаётся заблокированной.
    -- Поэтому параллельное закрытие заявки не сможет пройти проверку раньше, чем завершится наше удаление.
    DELETE FROM comments
    WHERE id = p_comment_id
      AND employee_id IS NOT NULL;

    RETURN FOUND;  -- FOUND показывает, была ли удалена строка.

END;
$$;