CREATE DATABASE IF NOT EXISTS security_system;
USE security_system;

CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50),
    risk_level VARCHAR(20)
) ENGINE=InnoDB;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50),
    password_hash VARCHAR(100),
    role_id INT,
    last_password_change DATE,
    CONSTRAINT fk_user_role FOREIGN KEY (role_id) REFERENCES roles(id)
) ENGINE=InnoDB;

CREATE TABLE login_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    attempt_time DATETIME,
    success TINYINT(1),
    note TEXT,
    CONSTRAINT fk_login_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;

INSERT INTO roles (role_name, risk_level) VALUES
('Admin', 'Extremely High'),
('Developer', 'High'),
('Intern', 'Terrifying');

INSERT INTO users (username, password_hash, role_id, last_password_change) VALUES
('admin', 'admin', 1, '2013-01-01'),
('john.dev', 'P@ssw0rd', 2, '2024-02-15'),
('intern42', 'azerty', 3, '2025-01-01');

INSERT INTO login_attempts (user_id, attempt_time, success, note) VALUES
(1, NOW(), 1,
 'Logged in successfully. Security team cried quietly.'),
(3, NOW(), 0,
 'Caps Lock was ON. Again.'),
(2, NOW(), 1,
 'Authenticated after resetting password for the 5th time this month.');
