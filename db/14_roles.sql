-- Роли и права доступа
-- Создаём двух пользователей приложения:
--    app_reader — для чтения данных
--    app_writer — для выполнения разрешённых операций
-- Пароли не записываем в SQL-файл. Получаем их из переменных окружения контейнера


-- Получаем пароли из переменных окружения
-- \getenv — команда программы psql. Она записывает значение переменной окружения во внутреннюю переменную psql
\getenv reader_password APP_READER_PASSWORD
\getenv writer_password APP_WRITER_PASSWORD


-- Создаём роль для чтения
CREATE ROLE app_reader
LOGIN PASSWORD :'reader_password';  -- LOGIN разрешает подключаться к PostgreSQL. PASSWORD задаёт пароль
-- Запись :'reader_password' означает, что psql безопасно подставит значение переменной


-- Создаём роль для разрешённых операций
CREATE ROLE app_writer
LOGIN PASSWORD :'writer_password'
IN ROLE app_reader;
-- IN ROLE app_reader добавляет app_writer в роль читателя,
-- поэтому app_writer сможет пользоваться правами чтения, выданными app_reader.


-- Запрещаем всем обычным пользователям автоматически вызывать функции схемы public
-- Отдельно разрешим только нужные функции
REVOKE EXECUTE ON ALL FUNCTIONS
IN SCHEMA public FROM PUBLIC;  -- PUBLIC здесь означает всех пользователей, а не название схемы


-- Убираем общие права на таблицы. Это не лишает владельца таблиц его прав.
REVOKE ALL ON ALL TABLES
IN SCHEMA public FROM PUBLIC;


-- Разрешаем обеим ролям пользоваться схемой public
GRANT USAGE ON SCHEMA public  -- USAGE позволяет обращаться к объектам схемы, но само по себе не даёт права читать таблицы
TO app_reader, app_writer;


-- Разрешаем читателю просматривать только подготовленные представления
-- Исходные таблицы tickets, comments и другие здесь не перечислены, поэтому прямого доступа к ним у роли не будет
GRANT SELECT ON  -- SELECT — право читать данные
    v_ticket_info,
    v_employee_stats,
    mv_ticket_report
TO app_reader;


-- Разрешаем app_writer выполнять защищённую бизнес-операцию закрытия заявки
-- SECURITY DEFINER у функции позволяет выполнить разрешённую операцию с правами владельца функции
GRANT EXECUTE ON FUNCTION  -- EXECUTE — право вызывать функцию
    safe_close_ticket(INTEGER)
TO app_writer;


-- Дополнительно разрешаем защищённое удаление ответа сотрудника.
-- Прямой DELETE из comments по-прежнему остаётся недоступен роли приложения.
GRANT EXECUTE ON FUNCTION
    safe_remove_employee_reply(INTEGER)
TO app_writer;