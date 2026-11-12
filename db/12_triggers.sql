
-- Лабораторная работа №3. Логика в базе
-- Тема №19: Служба поддержки
-- Файл 12_triggers.sql
-- Проверка бизнес-правила и сохранение истории заявок


-- 1. Добавляем дату последнего изменения заявки

-- ALTER TABLE изменяет структуру существующей таблицы.
-- ADD COLUMN добавляет новый столбец.
-- TIMESTAMPTZ хранит дату и время с учётом часового пояса.
-- DEFAULT CURRENT_TIMESTAMP задаёт начальное значение.
ALTER TABLE tickets
ADD COLUMN updated_at TIMESTAMPTZ NOT NULL
DEFAULT CURRENT_TIMESTAMP;


-- 2. Создаём триггер проверки бизнес-правила

-- Триггерная функция вызывается автоматически
-- при изменении заявки, если к ней привязан триггер.

-- RETURNS TRIGGER означает, что это функция для триггера.
CREATE FUNCTION check_ticket_close()
RETURNS TRIGGER
LANGUAGE plpgsql

AS $$
BEGIN

    -- NEW содержит новые значения изменяемой заявки.
    -- OLD содержит значения заявки до изменения.

    -- Проверяем, что статус меняется именно на closed.
    -- IS DISTINCT FROM сравнивает значения,
    -- в том числе корректно обрабатывает NULL.
    IF NEW.status = 'closed'
       AND OLD.status IS DISTINCT FROM 'closed' THEN

        -- EXISTS проверяет наличие хотя бы одной строки.
        -- NOT EXISTS означает, что подходящих строк нет.
        IF NOT EXISTS (
            SELECT 1
            FROM comments c

            -- Проверяем комментарии именно этой заявки.
            -- employee_id IS NOT NULL означает,
            -- что комментарий оставил сотрудник.
            WHERE c.ticket_id = NEW.id
              AND c.employee_id IS NOT NULL
        ) THEN

            -- Если сотрудник не ответил, выдаём ошибку.
            -- RAISE EXCEPTION прерывает изменение данных.
            RAISE EXCEPTION
                'Нельзя закрыть заявку % без ответа сотрудника',
                NEW.id;

        END IF;
    END IF;

    -- Разрешаем PostgreSQL сохранить новую строку,
    -- если проверка прошла успешно.
    RETURN NEW;
END;
$$;


-- CREATE TRIGGER связывает функцию с таблицей.
-- BEFORE UPDATE — проверяем до изменения заявки.
-- FOR EACH ROW — отдельно для каждой изменяемой строки.
CREATE TRIGGER trg_check_ticket_close
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION check_ticket_close();


-- 3. Создаём служебный триггер изменения даты

-- Эта функция автоматически обновляет updated_at
-- при каждом изменении заявки.
CREATE FUNCTION set_ticket_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql

AS $$
BEGIN

    -- Записываем текущее время в новую версию заявки.
    -- clock_timestamp() возвращает фактическое время.
    NEW.updated_at := clock_timestamp();

    RETURN NEW;
END;
$$;


-- Привязываем функцию к таблице tickets.
CREATE TRIGGER trg_ticket_updated_at
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION set_ticket_updated_at();


-- 4. ★★ Создаём таблицу истории изменений

-- История будет храниться отдельно от основных заявок.
-- Это позволяет посмотреть, что и когда изменилось.

CREATE TABLE ticket_history (
    -- Уникальный номер записи журнала.
    id BIGSERIAL PRIMARY KEY,

    -- Номер заявки, которую изменили.
    ticket_id INTEGER NOT NULL,

    -- Вид операции: INSERT, UPDATE или DELETE.
    operation VARCHAR(10) NOT NULL,

    -- Старая версия записи.
    old_data JSONB,

    -- Новая версия записи.
    new_data JSONB,

    -- Пользователь PostgreSQL, выполнивший операцию.
    changed_by TEXT NOT NULL,

    -- Фактическое время изменения.
    changed_at TIMESTAMPTZ NOT NULL
);


-- 5. ★★ Создаём функцию сохранения истории

CREATE FUNCTION save_ticket_history()
RETURNS TRIGGER
LANGUAGE plpgsql

AS $$
BEGIN

    -- TG_OP содержит название операции:
    -- INSERT, UPDATE или DELETE.

    IF TG_OP = 'INSERT' THEN

        -- При добавлении есть новая строка NEW,
        -- но старой строки OLD ещё не существует.
        INSERT INTO ticket_history (
            ticket_id, operation, old_data,
            new_data, changed_by, changed_at
        )
        VALUES (
            NEW.id,
            TG_OP,
            NULL,
            to_jsonb(NEW),
            session_user,
            clock_timestamp()
        );

    ELSIF TG_OP = 'UPDATE' THEN

        -- При изменении доступны обе версии записи.
        INSERT INTO ticket_history (
            ticket_id, operation, old_data,
            new_data, changed_by, changed_at
        )
        VALUES (
            NEW.id,
            TG_OP,
            to_jsonb(OLD),
            to_jsonb(NEW),
            session_user,
            clock_timestamp()
        );

    ELSIF TG_OP = 'DELETE' THEN

        -- При удалении новой строки уже нет.
        -- Поэтому сохраняем только OLD.
        INSERT INTO ticket_history (
            ticket_id, operation, old_data,
            new_data, changed_by, changed_at
        )
        VALUES (
            OLD.id,
            TG_OP,
            to_jsonb(OLD),
            NULL,
            session_user,
            clock_timestamp()
        );

    END IF;

    -- AFTER-триггер не изменяет сохраняемую строку.
    -- Поэтому возвращаемое значение здесь не используется.
    RETURN NULL;
END;
$$;


-- AFTER означает, что запись истории создаётся
-- после выполнения операции над заявкой.
-- Указываем все три вида изменений.
CREATE TRIGGER trg_ticket_history
AFTER INSERT OR UPDATE OR DELETE ON tickets
FOR EACH ROW
EXECUTE FUNCTION save_ticket_history();


-- 6. ★★ Функция получения состояния заявки на дату

-- Функция получает ID заявки и момент времени.
-- Возвращает версию заявки в формате JSONB.

CREATE FUNCTION ticket_state_at(
    p_ticket_id INTEGER,
    p_moment TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql

AS $$
DECLARE
    -- Сюда запишем найденное состояние заявки.
    v_state JSONB;

BEGIN

    -- Сначала ищем самое раннее изменение,
    -- которое произошло ПОСЛЕ указанного момента.
    --
    -- OLD этого изменения показывает,
    -- какой заявка была непосредственно перед ним.
    SELECT h.old_data
    INTO v_state
    FROM ticket_history h
    WHERE h.ticket_id = p_ticket_id
      AND h.changed_at > p_moment
    ORDER BY h.changed_at, h.id
    LIMIT 1;

    -- FOUND показывает, нашлась ли запись истории.
    -- Если нашлась, возвращаем её старое состояние.
    -- Оно может быть NULL, если заявка ещё не существовала.
    IF FOUND THEN
        RETURN v_state;
    END IF;

    -- Если более поздних изменений нет,
    -- ищем последнее изменение до указанного момента.
    SELECT h.new_data
    INTO v_state
    FROM ticket_history h
    WHERE h.ticket_id = p_ticket_id
      AND h.changed_at <= p_moment
    ORDER BY h.changed_at DESC, h.id DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN v_state;
    END IF;

    -- Если записей истории нет, проверяем текущую таблицу.
    -- Это полезно для старых заявок,
    -- которые существовали до создания журнала.
    SELECT to_jsonb(t)
    INTO v_state
    FROM tickets t
    WHERE t.id = p_ticket_id
      AND t.created_at <= p_moment;

    RETURN v_state;
END;
$$;