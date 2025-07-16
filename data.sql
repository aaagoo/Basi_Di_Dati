--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

-- Started on 2025-07-16 23:11:19

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
-- TOC entry 4993 (class 0 OID 16753)
-- Dependencies: 218
-- Data for Name: account; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.account (id, nomeutente, password) VALUES (2, 'aaagoo', 'agoago');
INSERT INTO public.account (id, nomeutente, password) VALUES (3, 'mt', 'fofo');
INSERT INTO public.account (id, nomeutente, password) VALUES (5, 'agoadmin', 'agoago');
INSERT INTO public.account (id, nomeutente, password) VALUES (7, 'mtmt', 'mtmt');


--
-- TOC entry 4995 (class 0 OID 16771)
-- Dependencies: 220
-- Data for Name: amministratore; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.amministratore (id) VALUES (3);
INSERT INTO public.amministratore (id) VALUES (5);


--
-- TOC entry 4996 (class 0 OID 16787)
-- Dependencies: 221
-- Data for Name: volo; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.volo (codice, compagnia_aerea, aeroporto_origine, aeroporto_destinazione, data_partenza, orario, ritardo, stato, tipo) VALUES ('GS9657', 'Easy Jet', 'Napoli', 'Berlino', '2025-08-01', '12:30:00', 0, 'PROGRAMMATO', 'PARTENZA');
INSERT INTO public.volo (codice, compagnia_aerea, aeroporto_origine, aeroporto_destinazione, data_partenza, orario, ritardo, stato, tipo) VALUES ('BG2254', 'British Airways', 'Napoli', 'Londra', '2025-08-03', '15:30:00', 0, 'PROGRAMMATO', 'PARTENZA');
INSERT INTO public.volo (codice, compagnia_aerea, aeroporto_origine, aeroporto_destinazione, data_partenza, orario, ritardo, stato, tipo) VALUES ('EJ6523', 'Alitalia', 'Mlano', 'Napoli', '2025-08-01', '09:30:00', 0, 'PROGRAMMATO', 'ARRIVO');
INSERT INTO public.volo (codice, compagnia_aerea, aeroporto_origine, aeroporto_destinazione, data_partenza, orario, ritardo, stato, tipo) VALUES ('ES6893', 'Ryanair', 'Madrid', 'Napoli', '2025-08-01', '14:00:00', 0, 'PROGRAMMATO', 'ARRIVO');
INSERT INTO public.volo (codice, compagnia_aerea, aeroporto_origine, aeroporto_destinazione, data_partenza, orario, ritardo, stato, tipo) VALUES ('IT6893', 'ITA Airways', 'Torino', 'Napoli', '2025-08-03', '19:30:00', 0, 'PROGRAMMATO', 'ARRIVO');
INSERT INTO public.volo (codice, compagnia_aerea, aeroporto_origine, aeroporto_destinazione, data_partenza, orario, ritardo, stato, tipo) VALUES ('AZ5476', 'Air France', 'Napoli', 'Parigi', '2025-08-01', '16:00:00', 0, 'PROGRAMMATO', 'PARTENZA');
INSERT INTO public.volo (codice, compagnia_aerea, aeroporto_origine, aeroporto_destinazione, data_partenza, orario, ritardo, stato, tipo) VALUES ('CC6034', 'ITA Airways', 'Napoli', 'Bari', '2025-08-02', '11:00:00', 10, 'IN_RITARDO', 'PARTENZA');


--
-- TOC entry 4998 (class 0 OID 16817)
-- Dependencies: 223
-- Data for Name: gate; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.gate (numero_gate, codice_volo) VALUES (4, 'AZ5476');


--
-- TOC entry 4997 (class 0 OID 16795)
-- Dependencies: 222
-- Data for Name: prenotazione; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.prenotazione (numero_biglietto, posto_assegnato, stato, nome_passeggero, cognome_passeggero, codice_volo, username_prenotazione) VALUES ('PRE000002', '29B', 'CONFERMATA', 'Mariateresa', 'Principato', 'AZ5476', 'aaagoo');
INSERT INTO public.prenotazione (numero_biglietto, posto_assegnato, stato, nome_passeggero, cognome_passeggero, codice_volo, username_prenotazione) VALUES ('PRE000001', '28E', 'CONFERMATA', 'Agostino', 'Sorrentino', 'AZ5476', 'aaagoo');


--
-- TOC entry 4994 (class 0 OID 16761)
-- Dependencies: 219
-- Data for Name: utente; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.utente (id, nome, cognome) VALUES (2, 'Agostino', 'Sorrentino');
INSERT INTO public.utente (id, nome, cognome) VALUES (7, 'Mariateresa', 'Principato');


--
-- TOC entry 5004 (class 0 OID 0)
-- Dependencies: 217
-- Name: account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.account_id_seq', 10, true);


-- Completed on 2025-07-16 23:11:19

--
-- PostgreSQL database dump complete
--

