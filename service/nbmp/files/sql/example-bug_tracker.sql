CREATE DATABASE IF NOT EXISTS bug_tracker;
USE bug_tracker;

CREATE TABLE developers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    favorite_excuse VARCHAR(100)
) ENGINE=InnoDB;

CREATE TABLE projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    deadline DATE
) ENGINE=InnoDB;

CREATE TABLE bugs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT,
    developer_id INT,
    title VARCHAR(100),
    severity VARCHAR(20),
    status VARCHAR(20),
    comment TEXT,
    CONSTRAINT fk_bug_project FOREIGN KEY (project_id) REFERENCES projects(id),
    CONSTRAINT fk_bug_developer FOREIGN KEY (developer_id) REFERENCES developers(id)
) ENGINE=InnoDB;

INSERT INTO developers (name, favorite_excuse) VALUES
('Alice', 'Works on my machine'),
('Bob', 'Probably a cache issue'),
('Charlie', 'Let’s rewrite it in Rust');

INSERT INTO projects (name, deadline) VALUES
('NextGen Website', '2025-12-31'),
('Mobile App v2', '2024-06-01');

INSERT INTO bugs (project_id, developer_id, title, severity, status, comment) VALUES
(1, 1, 'Quantum Bug', 'Critical', 'Open',
 'Bug disappears when debugger is attached.'),
(1, 2, 'Random Null Pointer', 'Major', 'In Progress',
 'Happens only on Fridays after 4pm.'),
(2, 3, 'UI Misaligned by 1px', 'Minor', 'Closed',
 'Caused a 2-hour meeting.');
