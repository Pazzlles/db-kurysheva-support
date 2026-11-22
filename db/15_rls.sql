
-- Лабораторная работа №4. Дополнительное задание ★★
-- Row Level Security (RLS)
--
-- Показываем ограничение доступа на уровне строк.
--
-- Для примера создаём внутренние заметки сотрудников.
-- Каждый пользователь сможет читать
-- только заметки, принадлежащие ему.


-- Создаём таблицу внутренних заметок.
--
-- id — уникальный номер заметки.
-- owner_name — имя роли, которой принадлежит заметка.
-- note — текст заметки.

CREATE TABLE private_notes (
    id SERIAL PRIMARY KEY,
    owner_name TEXT NOT NULL,
    note TEXT NOT NULL
);


-- Создаём две учебные роли.
--
-- NOLOGIN означает, что роли не могут
-- самостоятельно подключаться по паролю.
--
-- Для проверки будем временно переключаться
-- на них с помощью SET ROLE.

CREATE ROLE rls_user_1 NOLOGIN;

CREATE ROLE rls_user_2 NOLOGIN;


-- Разрешаем обеим ролям пользоваться схемой public.
--
-- USAGE нужен для обращения к объектам схемы.

GRANT USAGE ON SCHEMA public
TO rls_user_1, rls_user_2;


-- Разрешаем читать таблицу private_notes.
--
-- Без GRANT SELECT пользователи вообще
-- не смогли бы выполнять SELECT.
--
-- Но доступ к таблице ещё не означает,
-- что им разрешено видеть все её строки.

GRANT SELECT ON private_notes
TO rls_user_1, rls_user_2;


-- Включаем Row Level Security для таблицы.
--
-- После включения RLS PostgreSQL будет
-- применять политики доступа к её строкам.

ALTER TABLE private_notes
ENABLE ROW LEVEL SECURITY;


-- Создаём политику чтения собственных заметок.
--
-- CREATE POLICY задаёт правило доступа.
--
-- FOR SELECT означает, что политика
-- применяется при чтении данных.
--
-- TO перечисляет роли, для которых она действует.
--
-- USING определяет, какие строки разрешено видеть.
--
-- current_user возвращает текущую роль PostgreSQL.
--
-- Если owner_name совпадает с текущей ролью,
-- строка доступна. В противном случае скрыта.

CREATE POLICY read_own_notes
ON private_notes
FOR SELECT
TO rls_user_1, rls_user_2
USING (owner_name = current_user);