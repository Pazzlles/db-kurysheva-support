-- 1. Повтор email клиента
-- expect: error unique
INSERT INTO clients (name, email)
VALUES ('Test Client', 'anna@example.com');

-- 2. Недопустимый приоритет заявки
-- expect: error check
INSERT INTO tickets (client_id, category_id, title, description, priority)
VALUES (1, 1, 'Test', 'Test message', 5);

-- 3. Несуществующий клиент
-- expect: error fk
INSERT INTO tickets (client_id, category_id, title, description)
VALUES (99999, 1, 'Test', 'Test message');
