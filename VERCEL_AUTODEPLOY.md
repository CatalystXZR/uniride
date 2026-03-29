# Vercel Autodeploy (GitHub Actions)

Este proyecto ya queda preparado para deploy automatico a Vercel en cada push a `main`.

## Que se agrego

- Workflow: `.github/workflows/vercel-deploy.yml`
- Config SPA: `turnoapp/vercel.json`

El workflow:
1. Instala Flutter
2. Ejecuta `flutter pub get`
3. Build web release con `--dart-define`
4. Copia `vercel.json` al build final
5. Despliega a Vercel en produccion

## Secrets requeridos en GitHub

En tu repo: `Settings -> Secrets and variables -> Actions -> New repository secret`

Agrega estos 5:

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## Como obtener los valores

### 1) VERCEL_TOKEN
- Vercel -> `Settings -> Tokens` -> create token.

### 2) VERCEL_ORG_ID y VERCEL_PROJECT_ID
Opcion rapida local:

```bash
cd turnoapp
vercel link
cat .vercel/project.json
```

Desde ahi sacas:
- `orgId` -> `VERCEL_ORG_ID`
- `projectId` -> `VERCEL_PROJECT_ID`

### 3) SUPABASE_URL y SUPABASE_ANON_KEY
- Supabase Dashboard -> `Settings -> API`

## Activacion

Una vez cargados los secrets, cada push a `main` con cambios en `turnoapp/**` despliega solo.

## Verificacion

- GitHub -> `Actions` -> `Deploy TurnoApp to Vercel`
- Debe terminar en verde.
- Vercel dashboard debe mostrar nuevo deployment de produccion.
