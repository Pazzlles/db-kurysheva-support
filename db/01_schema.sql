-- Лабораторная работа №1. Тема №19: Служба поддержки
-- Создание таблиц, ключей и ограничений PostgreSQL 17

CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20)
);

CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    position VARCHAR(50) NOT NULL
);

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES clients(id)
        ON DELETE RESTRICT,
    employee_id INT REFERENCES employees(id)
        ON DELETE SET NULL,
    category_id INT NOT NULL REFERENCES categories(id)
        ON DELETE RESTRICT,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'new'
        CHECK (status IN ('new', 'in_progress', 'closed')),
    priority INT NOT NULL DEFAULT 2
        CHECK (priority BETWEEN 1 AND 3),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    ticket_id INT NOT NULL REFERENCES tickets(id)
        ON DELETE CASCADE,
    client_id INT REFERENCES clients(id)
        ON DELETE RESTRICT,
    employee_id INT REFERENCES employees(id)
        ON DELETE RESTRICT,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CHECK (
        (client_id IS NOT NULL AND employee_id IS NULL)
        OR
        (client_id IS NULL AND employee_id IS NOT NULL)
    )
);

CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- Связь многие-ко-многим между заявками и тегами
CREATE TABLE ticket_tags (
    ticket_id INT NOT NULL REFERENCES tickets(id)
        ON DELETE CASCADE,
    tag_id INT NOT NULL REFERENCES tags(id)
        ON DELETE RESTRICT,
    PRIMARY KEY (ticket_id, tag_id)
);
