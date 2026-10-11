-- Лабораторная работа №1. Генерация тестовых заявок

INSERT INTO tickets
(client_id, employee_id, category_id, title, description, status, priority)
SELECT
    (n % 10) + 1,
    (n % 10) + 1,
    (n % 10) + 1,
    'Заявка ' || n,
    'Тестовое обращение ' || n,
    'new',
    2
FROM generate_series(1, 1000) AS n;
