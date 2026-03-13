/**
 *
 * Project: TurnoApp
 *
 * Original Concept: Agustín Puelma, Cristobal Cordova, Carlos Ibarra
 *
 * Software Architecture & Code: Matías Toledo (catalystxzr)
 *
 * Description: Production-grade implementation for UDD carpooling system.
 *
 * Copyright (c) 2026. All rights reserved.
 *
 */

-- =============================================================
-- TurnoApp MVP — Migration 04: Seed Data
-- Universities and their campuses for the 5 target institutions.
-- Uses fixed UUIDs so re-running this migration is idempotent.
-- =============================================================

-- ── Universities ─────────────────────────────────────────────
insert into universities (id, code, name) values
  ('11111111-0000-0000-0000-000000000001', 'UDD',    'Universidad del Desarrollo'),
  ('11111111-0000-0000-0000-000000000002', 'UANDES', 'Universidad de los Andes'),
  ('11111111-0000-0000-0000-000000000003', 'PUC',    'Pontificia Universidad Católica de Chile'),
  ('11111111-0000-0000-0000-000000000004', 'UAI',    'Universidad Adolfo Ibáñez'),
  ('11111111-0000-0000-0000-000000000005', 'UNAB',   'Universidad Andrés Bello')
on conflict (id) do nothing;

-- ── Campuses ─────────────────────────────────────────────────

-- UDD
insert into campuses (id, university_id, name, commune) values
  ('22222222-0001-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Campus Concepción',   'Concepción'),
  ('22222222-0001-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', 'Campus Las Condes',   'Las Condes'),
  ('22222222-0001-0000-0000-000000000003', '11111111-0000-0000-0000-000000000001', 'Campus Viña del Mar', 'Viña del Mar')
on conflict (id) do nothing;

-- UANDES
insert into campuses (id, university_id, name, commune) values
  ('22222222-0002-0000-0000-000000000001', '11111111-0000-0000-0000-000000000002', 'Campus San Carlos de Apoquindo', 'Las Condes')
on conflict (id) do nothing;

-- PUC
insert into campuses (id, university_id, name, commune) values
  ('22222222-0003-0000-0000-000000000001', '11111111-0000-0000-0000-000000000003', 'Campus San Joaquín',   'San Joaquín'),
  ('22222222-0003-0000-0000-000000000002', '11111111-0000-0000-0000-000000000003', 'Campus Casa Central',  'Santiago'),
  ('22222222-0003-0000-0000-000000000003', '11111111-0000-0000-0000-000000000003', 'Campus Lo Contador',   'Providencia'),
  ('22222222-0003-0000-0000-000000000004', '11111111-0000-0000-0000-000000000003', 'Campus Oriente',       'Macul'),
  ('22222222-0003-0000-0000-000000000005', '11111111-0000-0000-0000-000000000003', 'Campus Villarrica',    'Villarrica')
on conflict (id) do nothing;

-- UAI
insert into campuses (id, university_id, name, commune) values
  ('22222222-0004-0000-0000-000000000001', '11111111-0000-0000-0000-000000000004', 'Campus Peñalolén',    'Peñalolén'),
  ('22222222-0004-0000-0000-000000000002', '11111111-0000-0000-0000-000000000004', 'Campus Vitacura',     'Vitacura'),
  ('22222222-0004-0000-0000-000000000003', '11111111-0000-0000-0000-000000000004', 'Campus Viña del Mar', 'Viña del Mar')
on conflict (id) do nothing;

-- UNAB
insert into campuses (id, university_id, name, commune) values
  ('22222222-0005-0000-0000-000000000001', '11111111-0000-0000-0000-000000000005', 'Campus República',    'Santiago'),
  ('22222222-0005-0000-0000-000000000002', '11111111-0000-0000-0000-000000000005', 'Campus Casanova',     'Las Condes'),
  ('22222222-0005-0000-0000-000000000003', '11111111-0000-0000-0000-000000000005', 'Campus Concepción',   'Concepción'),
  ('22222222-0005-0000-0000-000000000004', '11111111-0000-0000-0000-000000000005', 'Campus Viña del Mar', 'Viña del Mar')
on conflict (id) do nothing;
