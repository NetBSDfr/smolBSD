CREATE DATABASE IF NOT EXISTS infrastructure;
USE infrastructure;

CREATE TABLE data_centers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    location VARCHAR(50)
) ENGINE=InnoDB;

CREATE TABLE servers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data_center_id INT,
    hostname VARCHAR(50),
    os VARCHAR(50),
    status VARCHAR(30),
    uptime_days INT,
    CONSTRAINT fk_server_dc FOREIGN KEY (data_center_id) REFERENCES data_centers(id)
) ENGINE=InnoDB;

CREATE TABLE incidents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    server_id INT,
    incident_type VARCHAR(50),
    description TEXT,
    CONSTRAINT fk_incident_server FOREIGN KEY (server_id) REFERENCES servers(id)
) ENGINE=InnoDB;

INSERT INTO data_centers (name, location) VALUES
('Main DC', 'Unknown (classified)'),
('Backup DC', 'Basement under the stairs');

INSERT INTO servers (data_center_id, hostname, os, status, uptime_days) VALUES
(1, 'prod-server-01', 'Linux', 'Running', 487),
(1, 'legacy-monolith', 'Windows Server 2008', 'Undead', 3920),
(2, 'test-server', 'Linux', 'Crying softly', 3);

INSERT INTO incidents (server_id, incident_type, description) VALUES
(2, 'Reboot Attempt',
 'Server refused to reboot and threatened to break production.'),
(3, 'Disk Full',
 'Disk filled by log files nobody reads.'),
(1, 'Network Issue',
 'Fixed by unplugging and plugging the cable back in.');
