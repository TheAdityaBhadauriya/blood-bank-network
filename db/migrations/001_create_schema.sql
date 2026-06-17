-- ============================================================
-- Migration: 001_create_schema.sql
-- Description: All ENUM-style reference values via MySQL
--              compatible column definitions + core lookup data
-- ============================================================

CREATE DATABASE IF NOT EXISTS blood_bank_network;
USE blood_bank_network;

-- ============================================================
-- TABLE: blood_banks
-- Central storage and processing facilities
-- ============================================================
CREATE TABLE blood_banks (
    bank_id           INT             AUTO_INCREMENT PRIMARY KEY,
    name              VARCHAR(200)    NOT NULL,
    city              VARCHAR(100)    NOT NULL,
    phone             VARCHAR(20)     NOT NULL,
    storage_capacity  INT             NOT NULL,
    operating_hours   VARCHAR(100)    NOT NULL,
    is_active         TINYINT(1)      NOT NULL DEFAULT 1,
    created_at        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_storage_capacity
        CHECK (storage_capacity > 0)
);

-- ============================================================
-- TABLE: staff
-- Blood bank employees
-- ============================================================
CREATE TABLE staff (
    staff_id    INT             AUTO_INCREMENT PRIMARY KEY,
    bank_id     INT             NOT NULL,
    full_name   VARCHAR(150)    NOT NULL,
    role        ENUM('PHLEBOTOMIST','LAB_TECH','ADMIN','DRIVER')
                                NOT NULL,
    phone       VARCHAR(20)     NOT NULL UNIQUE,
    email       VARCHAR(255)    UNIQUE,
    is_active   TINYINT(1)      NOT NULL DEFAULT 1,
    hired_at    DATE            NOT NULL,

    CONSTRAINT fk_staff_bank
        FOREIGN KEY (bank_id)
        REFERENCES blood_banks(bank_id)
        ON DELETE RESTRICT
);

-- ============================================================
-- TABLE: donors
-- Registered blood donors
-- ============================================================
CREATE TABLE donors (
    donor_id            INT             AUTO_INCREMENT PRIMARY KEY,
    full_name           VARCHAR(150)    NOT NULL,
    blood_type          ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-')
                                        NOT NULL,
    phone               VARCHAR(20)     NOT NULL UNIQUE,
    email               VARCHAR(255)    UNIQUE,
    date_of_birth       DATE            NOT NULL,
    city                VARCHAR(100)    NOT NULL,
    is_eligible         TINYINT(1)      NOT NULL DEFAULT 1,
    last_donation_date  DATE,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_donor_age
        CHECK (date_of_birth <= DATE_SUB(CURDATE(), INTERVAL 18 YEAR))
);

-- ============================================================
-- TABLE: hospitals
-- Receiving hospitals
-- ============================================================
CREATE TABLE hospitals (
    hospital_id     INT             AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(200)    NOT NULL,
    city            VARCHAR(100)    NOT NULL,
    contact_phone   VARCHAR(20)     NOT NULL,
    license_number  VARCHAR(50)     NOT NULL UNIQUE,
    hospital_type   ENUM('GOVT','PRIVATE','TRUST')
                                    NOT NULL,
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- TABLE: doctors
-- Doctors who raise blood requests at hospitals
-- ============================================================
CREATE TABLE doctors (
    doctor_id        INT             AUTO_INCREMENT PRIMARY KEY,
    hospital_id      INT             NOT NULL,
    full_name        VARCHAR(150)    NOT NULL,
    specialization   VARCHAR(100)    NOT NULL,
    phone            VARCHAR(20)     NOT NULL UNIQUE,
    license_number   VARCHAR(50)     NOT NULL UNIQUE,

    CONSTRAINT fk_doctor_hospital
        FOREIGN KEY (hospital_id)
        REFERENCES hospitals(hospital_id)
        ON DELETE RESTRICT
);

-- ============================================================
-- TABLE: patients
-- Blood recipients admitted at hospitals
-- ============================================================
CREATE TABLE patients (
    patient_id      INT             AUTO_INCREMENT PRIMARY KEY,
    hospital_id     INT             NOT NULL,
    full_name       VARCHAR(150)    NOT NULL,
    blood_type      ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-')
                                    NOT NULL,
    diagnosis       TEXT,
    admitted_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    discharged_at   TIMESTAMP,

    CONSTRAINT fk_patient_hospital
        FOREIGN KEY (hospital_id)
        REFERENCES hospitals(hospital_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_discharge_after_admit
        CHECK (
            discharged_at IS NULL
            OR discharged_at > admitted_at
        )
);

-- ============================================================
-- TABLE: donation_camps
-- Temporary blood donation drives
-- ============================================================
CREATE TABLE donation_camps (
    camp_id          INT             AUTO_INCREMENT PRIMARY KEY,
    bank_id          INT             NOT NULL,
    name             VARCHAR(200)    NOT NULL,
    organizer        VARCHAR(150)    NOT NULL,
    location         TEXT            NOT NULL,
    city             VARCHAR(100)    NOT NULL,
    scheduled_date   DATE            NOT NULL,
    slots_available  INT             NOT NULL,
    is_cancelled     TINYINT(1)      NOT NULL DEFAULT 0,

    CONSTRAINT fk_camp_bank
        FOREIGN KEY (bank_id)
        REFERENCES blood_banks(bank_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_slots_positive
        CHECK (slots_available > 0)
);

-- ============================================================
-- TABLE: donor_appointments
-- A donor booking a slot to donate
-- ============================================================
CREATE TABLE donor_appointments (
    appointment_id  INT         AUTO_INCREMENT PRIMARY KEY,
    donor_id        INT         NOT NULL,
    camp_id         INT,
    bank_id         INT,
    scheduled_at    TIMESTAMP   NOT NULL,
    status          ENUM('SCHEDULED','COMPLETED','CANCELLED','NO_SHOW')
                                NOT NULL DEFAULT 'SCHEDULED',

    CONSTRAINT fk_appt_donor
        FOREIGN KEY (donor_id)
        REFERENCES donors(donor_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_appt_camp
        FOREIGN KEY (camp_id)
        REFERENCES donation_camps(camp_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_appt_bank
        FOREIGN KEY (bank_id)
        REFERENCES blood_banks(bank_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_appt_location
        CHECK (
            (camp_id IS NOT NULL AND bank_id IS NULL)
            OR (camp_id IS NULL AND bank_id IS NOT NULL)
        )
);

-- ============================================================
-- TABLE: donations
-- The actual donation event linking donor to bank/camp
-- ============================================================
CREATE TABLE donations (
    donation_id  INT         AUTO_INCREMENT PRIMARY KEY,
    donor_id     INT         NOT NULL,
    bank_id      INT         NOT NULL,
    camp_id      INT,
    staff_id     INT         NOT NULL,
    donated_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    volume_ml    INT         NOT NULL DEFAULT 450,
    notes        TEXT,

    CONSTRAINT fk_donation_donor
        FOREIGN KEY (donor_id)
        REFERENCES donors(donor_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_donation_bank
        FOREIGN KEY (bank_id)
        REFERENCES blood_banks(bank_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_donation_camp
        FOREIGN KEY (camp_id)
        REFERENCES donation_camps(camp_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_donation_staff
        FOREIGN KEY (staff_id)
        REFERENCES staff(staff_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_donation_volume
        CHECK (volume_ml BETWEEN 400 AND 500)
);

-- ============================================================
-- TABLE: blood_inventory
-- Individual physical blood bags
-- ============================================================
CREATE TABLE blood_inventory (
    bag_id           INT         AUTO_INCREMENT PRIMARY KEY,
    donation_id      INT         NOT NULL,
    bank_id          INT         NOT NULL,
    blood_type       ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-')
                                 NOT NULL,
    collection_date  DATE        NOT NULL,
    expiry_date      DATE        NOT NULL,
    bag_status       ENUM('QUARANTINE','AVAILABLE','RESERVED','USED','DISCARDED')
                                 NOT NULL DEFAULT 'QUARANTINE',
    volume_ml        INT         NOT NULL DEFAULT 450,
    updated_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_bag_donation
        FOREIGN KEY (donation_id)
        REFERENCES donations(donation_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bag_bank
        FOREIGN KEY (bank_id)
        REFERENCES blood_banks(bank_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_expiry_after_collection
        CHECK (expiry_date > collection_date),

    CONSTRAINT chk_bag_expiry_window
        CHECK (expiry_date <= DATE_ADD(collection_date, INTERVAL 42 DAY)),

    CONSTRAINT chk_bag_volume
        CHECK (volume_ml BETWEEN 400 AND 500)
);

-- ============================================================
-- TABLE: lab_tests
-- Screening tests run on each bag before release
-- ============================================================
CREATE TABLE lab_tests (
    test_id     INT         AUTO_INCREMENT PRIMARY KEY,
    bag_id      INT         NOT NULL,
    staff_id    INT         NOT NULL,
    test_type   ENUM('HIV','HEP_B','HEP_C','SYPHILIS','MALARIA')
                            NOT NULL,
    result      ENUM('PENDING','NEGATIVE','POSITIVE')
                            NOT NULL DEFAULT 'PENDING',
    tested_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_test_bag
        FOREIGN KEY (bag_id)
        REFERENCES blood_inventory(bag_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_test_staff
        FOREIGN KEY (staff_id)
        REFERENCES staff(staff_id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_bag_test_type
        UNIQUE (bag_id, test_type)
);

-- ============================================================
-- TABLE: hospital_requests
-- A hospital's formal request for blood units
-- ============================================================
CREATE TABLE hospital_requests (
    request_id        INT         AUTO_INCREMENT PRIMARY KEY,
    hospital_id       INT         NOT NULL,
    doctor_id         INT         NOT NULL,
    patient_id        INT,
    blood_type        ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-')
                                  NOT NULL,
    units_requested   INT         NOT NULL,
    units_fulfilled   INT         NOT NULL DEFAULT 0,
    request_status    ENUM('PENDING','PARTIAL','FULFILLED','CANCELLED')
                                  NOT NULL DEFAULT 'PENDING',
    request_priority  ENUM('ROUTINE','URGENT','CRITICAL')
                                  NOT NULL DEFAULT 'ROUTINE',
    requested_at      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fulfilled_at      TIMESTAMP,
    notes             TEXT,

    CONSTRAINT fk_request_hospital
        FOREIGN KEY (hospital_id)
        REFERENCES hospitals(hospital_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_request_doctor
        FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_request_patient
        FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_units_positive
        CHECK (units_requested > 0),

    CONSTRAINT chk_units_fulfilled
        CHECK (
            units_fulfilled >= 0
            AND units_fulfilled <= units_requested
        )
);

-- ============================================================
-- TABLE: request_allocations
-- Links specific bags to a specific request
-- ============================================================
CREATE TABLE request_allocations (
    allocation_id   INT         AUTO_INCREMENT PRIMARY KEY,
    request_id      INT         NOT NULL,
    bag_id          INT         NOT NULL UNIQUE,
    allocated_by    INT         NOT NULL,
    allocated_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_alloc_request
        FOREIGN KEY (request_id)
        REFERENCES hospital_requests(request_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_alloc_bag
        FOREIGN KEY (bag_id)
        REFERENCES blood_inventory(bag_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_alloc_staff
        FOREIGN KEY (allocated_by)
        REFERENCES staff(staff_id)
        ON DELETE RESTRICT
);

-- ============================================================
-- TABLE: transfusion_records
-- Confirms blood was administered to a patient
-- ============================================================
CREATE TABLE transfusion_records (
    transfusion_id   INT         AUTO_INCREMENT PRIMARY KEY,
    request_id       INT         NOT NULL,
    patient_id       INT         NOT NULL,
    bag_id           INT         NOT NULL UNIQUE,
    transfused_by    INT         NOT NULL,
    transfused_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    outcome          ENUM('PENDING','SUCCESSFUL','ADVERSE_REACTION')
                                 NOT NULL DEFAULT 'PENDING',

    CONSTRAINT fk_trans_request
        FOREIGN KEY (request_id)
        REFERENCES hospital_requests(request_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_trans_patient
        FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_trans_bag
        FOREIGN KEY (bag_id)
        REFERENCES blood_inventory(bag_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_trans_doctor
        FOREIGN KEY (transfused_by)
        REFERENCES doctors(doctor_id)
        ON DELETE RESTRICT
);

-- ============================================================
-- TABLE: transfers
-- Moving bags between blood banks
-- ============================================================
CREATE TABLE transfers (
    transfer_id      INT         AUTO_INCREMENT PRIMARY KEY,
    bag_id           INT         NOT NULL,
    from_bank_id     INT         NOT NULL,
    to_bank_id       INT         NOT NULL,
    transferred_by   INT         NOT NULL,
    transferred_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason           TEXT,

    CONSTRAINT fk_transfer_bag
        FOREIGN KEY (bag_id)
        REFERENCES blood_inventory(bag_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transfer_from
        FOREIGN KEY (from_bank_id)
        REFERENCES blood_banks(bank_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transfer_to
        FOREIGN KEY (to_bank_id)
        REFERENCES blood_banks(bank_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transfer_staff
        FOREIGN KEY (transferred_by)
        REFERENCES staff(staff_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_transfer_different_banks
        CHECK (from_bank_id <> to_bank_id)
);

-- ============================================================
-- TABLE: notifications
-- Alerts sent to donors, hospitals, or staff
-- ============================================================
CREATE TABLE notifications (
    notification_id  INT         AUTO_INCREMENT PRIMARY KEY,
    recipient_type   ENUM('DONOR','HOSPITAL','STAFF')
                                 NOT NULL,
    recipient_id     INT         NOT NULL,
    message          TEXT        NOT NULL,
    channel          ENUM('SMS','EMAIL','SYSTEM')
                                 NOT NULL,
    sent_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_read          TINYINT(1)  NOT NULL DEFAULT 0
);