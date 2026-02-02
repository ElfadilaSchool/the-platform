--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('17eab49d-0e03-4c68-bfc4-69999f93c5f3', 'employee2', '$2b$10$VWXYZAB1234567890HASHEDPASS4', 'Employee', '2025-08-27 12:35:11.647736', '2025-08-27 12:35:11.647736');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('f9a728f6-2aa9-4f8e-a544-4a05b9269dae', 'hr.manager', '$2b$10$ABCDEFG1234567890HASHEDPASS1', 'Department_Responsible', '2025-08-27 12:35:11.647736', '2025-09-03 09:59:38.850965');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('6d927a2a-83ba-4a6e-81d5-5d53d6457b43', 'directeur@entreprise.com', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Director', '2025-09-09 09:32:33.196958', '2025-09-09 09:32:33.196958');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('eef65169-a61e-45bf-b7ed-c7897d7443d6', 'employee1', '$2b$10$OPQRSTU1234567890HASHEDPASS3', 'Director', '2025-08-27 12:35:11.647736', '2025-09-09 09:51:29.624829');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('ded61506-b389-4004-83f8-33eed0ea6c76', 'resp_info', '$2b$10$ABcXyZ1234567890abcdefgH', 'Department_Responsible', '2025-09-09 11:53:26.882277', '2025-09-09 11:53:26.882277');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('35ab1996-5661-468b-8368-f4ebf68d01cb', 'resp_autre', '$2b$10$IJkLmN1234567890opqrstuV', 'Department_Responsible', '2025-09-09 11:53:26.882277', '2025-09-09 11:53:26.882277');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('7c1b6237-e8ec-4b90-b519-e7be3ce4889e', 'emp1', '$2b$10$QRsTuV1234567890wxyzabcD', 'Employee', '2025-09-09 11:53:26.882277', '2025-09-09 11:53:26.882277');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('c1af6477-ba37-48d7-b06c-a5c33820d36c', 'emp2', '$2b$10$WxYzAb1234567890cdefghiJ', 'Employee', '2025-09-09 11:53:26.882277', '2025-09-09 11:53:26.882277');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('483bba2c-4b12-4dc7-8449-b69931643020', 'emp3', '$2b$10$KlMnOp1234567890qrstuvwX', 'Employee', '2025-09-09 11:53:26.882277', '2025-09-09 11:53:26.882277');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('2e7b3b05-aa3a-407f-abb1-bc52b216102e', 'emp4', '$2b$10$EFgHiJ1234567890klmnopqR', 'Employee', '2025-09-09 11:53:26.882277', '2025-09-09 11:53:26.882277');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('f2de5462-7c21-4e9c-b070-283c28429007', 'dept.resp', '$2b$10$HIJKLMN1234567890HASHEDPASS2', 'Department_Responsible', '2025-08-27 12:35:11.647736', '2025-09-09 12:08:31.851879');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('e6a73462-6516-415b-b188-7352267c17e7', 'directeur.general', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Director', '2025-09-10 12:01:02.512829', '2025-09-10 12:01:02.512829');
INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at) VALUES ('79f034a9-ee01-4de2-9238-549e53bb794f', 'direction.general', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Director', '2025-09-10 12:02:51.07894', '2025-09-10 12:02:51.07894');


--
-- PostgreSQL database dump complete
--

